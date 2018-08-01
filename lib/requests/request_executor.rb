require "uri"
require "time"
require "net/http"
require "openssl"
require "concurrent"
require "constants/database"
require "constants/documents"
require "database/exceptions"
require "database/commands"
require "documents/conventions"
require "requests/request_helpers"
require "utilities/observable"
require "auth/auth_options"
require "requests/http_cache"
require "requests/http_cache_item"
require "utilities/reference"

module RavenDB
  class RequestExecutor
    include Observable

    MAX_FIRST_TOPOLOGY_UPDATES_TRIES = 5

    TOPOLOGY_ETAG = "Topology-Etag".freeze
    CLIENT_CONFIGURATION_ETAG = "Client-Configuration-Etag".freeze
    REFRESH_TOPOLOGY = "Refresh-Topology".freeze
    REFRESH_CLIENT_CONFIGURATION = "Refresh-Client-Configuration".freeze

    ALL_NET_HTTP_ERRORS = [
      Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
      SocketError
    ].freeze

    attr_reader :database_name
    attr_accessor :request_post_processor
    attr_accessor :certificate
    attr_reader :conventions

    def initialize(database_name:, conventions: nil, initial_urls: [], without_topology: false, auth_options: nil,
                   topology_etag: 0, single_node_topology: nil, disable_configuration_updates: false)

      urls = initial_urls

      @headers = {
        "Accept" => "application/json",
        "Raven-Client-Version" => RavenDB::VERSION
      }

      @conventions = DocumentConventions.new # ?
      @_disposed = false
      @database_name = database_name
      @_first_topology_updates_tries = 0
      @_last_known_urls = nil
      @_failed_nodes_statuses = {}
      @_first_topology_update = nil
      @_first_topology_update_exception = nil
      @_node_selector = nil
      @_without_topology = without_topology
      @_topology_etag = topology_etag
      @_await_first_topology_lock = Mutex.new
      @_update_topology_lock = Mutex.new
      @_update_failed_node_timer_lock = Mutex.new
      @_auth_options = nil
      @_read_balance_behavior = :none
      @request_post_processor = nil
      @client_configuration_etag = nil
      @number_of_server_requests = Concurrent::AtomicFixnum.new
      @cache = HttpCache.new(size: conventions&.max_http_cache_size)
      @_update_client_configuration_semaphore = Concurrent::Semaphore.new(1)
      @_disable_client_configuration_updates = disable_configuration_updates
      @_disable_topology_updates = disable_configuration_updates

      @self_lock = Mutex.new

      @_failed_nodes_timers = ConcurrentHashMap.new

      if auth_options
        @_auth_options = auth_options

        unless auth_options.is_a?(AuthOptions)
          raise ArgumentError, "Invalid auth options provided (expected RavenDB::AuthOptions, got #{@_auth_options.class})"
        end
      end

      if @_without_topology && single_node_topology
        @_node_selector = NodeSelector.new(self, single_node_topology)
      else
        @_first_topology_update = first_topology_update(input_urls: urls)
      end
    end

    def synchronized
      @self_lock.synchronize do
        yield
      end
    end

    def self.valid_url?(url)
      uri = URI.parse(url)
      return false unless uri.is_a?(URI::HTTP)
      return false unless uri.host
      true
    rescue URI::InvalidURIError
      false
    end

    def self.validate_urls(urls:, certificate: nil)
      require_https = !certificate.nil?
      clean_urls = urls.map do |url|
        raise "The url '#{url}' is not valid." unless valid_url?(url)
        require_https |= url.start_with?("https://")
        url.gsub(/\/+$/, "")
      end
      return clean_urls unless require_https
      urls.each do |url|
        next unless url.start_with?("http://")
        unless certificate.nil?
          raise "The url '#{url}' is using HTTP, but a certificate is specified, which require us to use HTTPS."
        end
        raise "The url '#{url}' is using HTTP, but other urls are using HTTPS, and mixing of HTTP and HTTPS is not allowed."
      end
      clean_urls
    end

    def first_topology_update(input_urls:)
      initial_urls = RequestExecutor.validate_urls(urls: input_urls, certificate: certificate)

      func = lambda do
        list = {}

        return if initial_urls.any? do |url|
          begin
            server_node = ServerNode.new(url, database_name)

            update_topology_async(node: server_node).value!

            initialize_update_topology_timer

            @_topology_taken_from_node = server_node

            true
          rescue AuthorizationException
            raise
          rescue DatabaseDoesNotExistException => e
            RavenDB.logger.warn(e)
            # Will happen on all node in the cluster,
            # so errors immediately
            @_last_known_urls = initial_urls
            raise e
          rescue StandardError => e
            RavenDB.logger.warn(e)
            if initial_urls.empty?
              @_last_known_urls = initial_urls
              raise RuntimeError.new("Cannot get topology from server: " + url, e)
            end

            list[url] = e

            false
          end
        end

        topology = Topology.new(@_topology_etag)

        topology_nodes = self.topology_nodes
        if topology_nodes.nil?
          topology_nodes = initial_urls.map do |url|
            ServerNode.new(url, database_name, "!")
          end
        end

        topology.nodes = topology_nodes

        @_node_selector = NodeSelector.new(self, topology)

        if !initial_urls.nil? && !initial_urls.empty?
          initialize_update_topology_timer
          return
        end

        @_last_known_urls = initial_urls
        details = list.map { |key, value| "#{key} -> #{value&.getMessage}" }.join(", ")
        throw_exceptions(details)
      end

      Concurrent::Future.execute(&func)
    end

    def initialize_update_topology_timer
      return if @_update_topology_timer

      synchronized do
        next if @_update_topology_timer

        @_update_topology_timer = Concurrent::TimerTask.new(execution_interval: 60, timeout_interval: 60) do
          update_topology_callback
        end
      end
    end

    def self.create(urls, database = nil, auth_options = nil)
      new(database_name: database,
          without_topology: false,
          initial_urls: urls.clone,
          auth_options: auth_options)
    end

    def self.create_for_single_node(url, database = nil, auth_options = nil, disable_configuration_updates: false)
      topology = Topology.new(-1, [ServerNode.new(url, database)])

      new(database_name: database,
          without_topology: true,
          single_node_topology: topology,
          topology_etag: -2,
          auth_options: auth_options,
          disable_configuration_updates: disable_configuration_updates
         )
    end

    def dispose
      return if @_disposed

      @_disposed = true
      cancel_failing_nodes_timers
    end

    def topology_nodes
      @_node_selector&.topology&.nodes&.dup&.freeze
    end

    def url
      @_node_selector&.preferred_node&.url
    end

    def create_request(node:, command:)
      request = command.create_request(node)

      unless request.key?("Raven-Client-Version")
        request["Raven-Client-Version"] = RavenDB::VERSION
      end

      request_post_processor&.call(request)

      request
    end

    def get_from_cache(command, url, cached_change_vector, cached_value)
      if command.can_cache? && command.read_request? && command.response_type == :object
        return cache.get(url, cached_change_vector, cached_value)
      end

      cached_change_vector.value = nil
      cached_value.value = nil
      HttpCache::ReleaseCacheItem.new(nil)
    end

    def should_execute_on_all(chosen_node, command)
      return false unless @_read_balance_behavior == :fastest_node
      return false if @_node_selector.nil?
      return false unless @_node_selector.in_speed_test_phase?
      return false unless @_node_selector.topology.nodes.size > 1
      return false unless command.read_request?
      return false unless command.response_type == :object
      return false if chosen_node.nil?
      true
    end

    def throw_failed_to_contact_all_nodes(command, request, e, timeout_exception)
      message = "Tried to send #{command.class} request via #{request.method} #{request.uri} to all configured nodes in the topology, " \
        " all of them seem to be down or not responding. I've tried to access the following nodes: "

      message += @_node_selector.topology.nodes.map(&:url).join(", ") if @_node_selector

      unless @_topology_taken_from_node.nil?
        message += "\nI was able to fetch #{@_topology_taken_from_node.database} topology from #{@_topology_taken_from_node.url}.\n"
        if @_node_selector
          nodes = @_node_selector.topology.nodes.map { |n| "(url: #{n.url}, clusterTag: #{n.cluster_tag}, serverRole: #{n.server_role})" }.join(", ")
          message += "Fetched topology: " + nodes
        end
      end

      raise AllTopologyNodesDownException.new(message, timeout_exception || e)
    end

    def handle_unsuccessful_response(chosen_node, node_index, command, request, response, url, session_info, should_retry)
      case response
      when Net::HTTPNotFound
        @cache.not_found = url
        case command.response_type
        when :empty
          return true
        when :object
          command.set_response(response)
        else
          command.set_response_raw(response)
        end
        return true
      when Net::HTTPForbidden # TBD: include info about certificates
        raise AuthorizationException, "Forbidden access to #{chosen_node.database}@#{chosen_node.url}, #{request.method} #{request.uri}"
      when Net::HTTPGone # request not relevant for the chosen node - the database has been moved to a different one
        return false unless should_retry
        update_topology_async(node: chosen_node, force_update: true).value!
        current_node, current_index = choose_node_for_request(command, session_info)
        execute(current_node, current_index, command, false, session_info)
        return true
      when Net::HTTPGatewayTimeOut, Net::HTTPRequestTimeOut, Net::HTTPBadGateway, Net::HTTPServiceUnavailable
        handle_server_down(url, chosen_node, node_index, command, request, response, nil, session_info)
      when Net::HTTPConflict
        handle_conflict(response)
      else
        command.on_response_failure(response)
        ExceptionsFactory.raise_from(response)
      end
      false
    rescue *ALL_NET_HTTP_ERRORS => e
      ExceptionsFactory.raise_exception(e)
    end

    def execute(command, chosen_node: nil, node_index: nil, should_retry: false, session_info: nil)
      topology_update = @_first_topology_update

      if chosen_node.nil?
        if topology_update&.fulfilled? || @_disable_topology_updates
          current_node, current_index = choose_node_for_request(command, session_info)
          return execute(command, chosen_node: current_node, node_index: current_index, should_retry: should_retry, session_info: session_info)
        else
          return unlikely_execute(command: command, topology_update: topology_update, session_info: session_info)
        end
      end

      request = create_request(node: chosen_node, command: command)
      cached_change_vector = Reference.new
      cached_value = Reference.new
      cached_item = get_from_cache(command, request.path, cached_change_vector, cached_value)
      unless cached_change_vector.value.nil?
        aggressive_cache_options = AggressiveCaching.get
        if !aggressive_cache_options.nil? &&
           cached_item.age.compare_to(aggressive_cache_options.duration) < 0 &&
           !cached_item.might_have_been_modified &&
           command.can_cache_aggressively?

          command.set_response(cached_value.value, true)
          return
        end
        request.add_header("If-None-Match", "\"#{cached_change_vector.value}\"")
      end
      unless @_disable_client_configuration_updates
        request[CLIENT_CONFIGURATION_ETAG] = "\"#{@client_configuration_etag}\""
      end
      request[TOPOLOGY_ETAG] = "\"#{@topology_etag}\"" unless @_disable_topology_updates
      response = nil
      begin
        @number_of_server_requests.increment
        response = if should_execute_on_all(chosen_node, command)
                     execute_on_all_to_figure_out_the_fastest(chosen_node, command)
                   else
                     command.send_request(http_client(chosen_node), request)
                   end
      rescue *ALL_NET_HTTP_ERRORS => e
        raise e unless should_retry
        unless handle_server_down(request.path, chosen_node, node_index, command, request, response, e, session_info)
          throw_failed_to_contact_all_nodes(command, request, e, nil)
        end
        return
      end
      command.status_code = response.code
      refresh_topology = response[REFRESH_TOPOLOGY] || false
      refresh_client_configuration = response[REFRESH_CLIENT_CONFIGURATION] || false
      begin
        if response.is_a?(Net::HTTPNotModified)
          cached_item.not_modified
          if command.response_type == :object
            command.set_response(cached_value.value || response)
          end
          return
        end
        if response.code.to_i >= 400
          unless handle_unsuccessful_response(chosen_node, node_index, command, request, response, request.path, session_info, should_retry)
            db_missing_header = response["Database-Missing"]
            unless db_missing_header.nil?
              raise DatabaseDoesNotExistException, db_missing_header
            end
            if command.failed_nodes.empty?
              raise "Received unsuccessful response and couldn't recover from it. Also, no record of exceptions per failed nodes. This is weird and should not happen."
            end
            if command.failed_nodes.size == 1
              values = command.failed_nodes.values
              if values.count > 0
                raise RuntimeException, values[0]
              end
            end
            raise "Received unsuccessful response from all servers and couldn't recover from it."
          end
          return
        end
        command.process_response(@cache, response, request.path, conventions: conventions)
        @_last_returned_response = Date.new
      ensure
        if refresh_topology || refresh_client_configuration
          server_node = ServerNode.new
          server_node.url = chosen_node.url
          server_node.database = @_database_name
          topology_task = refresh_topology ? update_topology_async(server_node, 0) : Concurrent::Future.execute { false }
          client_configuration = refresh_client_configuration ? update_client_configuration_async : Concurrent::Future.execute { false }
          [topology_task, client_configuration].each(&:value!)
        end
      end

      nil
    end

    def handle_conflict(response)
      ExceptionsFactory.raise_from(response)
    end

    def update_client_configuration_async
      return Concurrent::Future.execute { false } if @_disposed

      Concurrent::Future.execute do
        @_update_client_configuration_semaphore.acquire
        old_disable_client_configuration_updates = @_disable_client_configuration_updates
        @_disable_client_configuration_updates = true
        begin
          return if @_disposed
          command = GetClientConfigurationOperation::GetClientConfigurationCommand.new
          current_index, current_node = choose_node_for_request(command, nil)
          execute(command, chosen_node: current_node, node_index: current_index)
          result = command.result
          return if result.nil?
          @conventions.update_from(result.configuration)
          @client_configuration_etag = result.etag
        ensure
          @_disable_client_configuration_updates = old_disable_client_configuration_updates
          @_update_client_configuration_semaphore.release
        end
      end
    end

    def unlikely_execute(command:, topology_update:, session_info:)
      begin
        if topology_update.nil?

          synchronized do
            if @_first_topology_update.nil?
              raise "No known topology and no previously known one, cannot proceed, likely a bug" if @_last_known_urls.nil?

              @_first_topology_update = first_topology_update(@_last_known_urls)
            end

            topology_update = @_first_topology_update
          end
        end

        topology_update.value!
      rescue Concurrent::CancelledOperationError => e
        synchronized do
          if @_first_topology_update == topology_update
            @_first_topology_update = nil # next request will raise it
          end
        end

        raise ExceptionsUtils.unwrap_exception(e)
      end

      current_node, current_index = choose_node_for_request(command, session_info)
      execute(command,
              chosen_node: current_node,
              node_index: current_index,
              should_retry: true,
              session_info:  session_info)
    end

    def choose_node_for_request(cmd, session_info)
      raise "@_node_selector empty" if @_node_selector.nil?

      return @_node_selector.preferred_node_and_index unless cmd.read_request?

      case @_read_balance_behavior
      when :none
        return @_node_selector.preferred_node_and_index
      when :round_robin
        return @_node_selector.node_by_session_id(!session_info.nil? ? session_info.get_session_id : 0)
      when :fastest_node
        return @_node_selector.fastest_node
      else
        raise ArgumentError
      end
    end

    def update_topology_async(node:, timeout: nil, force_update: false)
      return Concurrent::Future.execute { false } if disposed?

      Concurrent::Future.execute do
        next false if disposed?

        command = get_update_topology_command_class.new
        execute(command, chosen_node: node)

        if @_node_selector.nil?
          @_node_selector = NodeSelector.new(self, command.result)
        end

        @_topology_etag = @_node_selector.topology.etag

        true
      end
    end

    protected

    def first_topology_update_tries_expired?
      @_first_topology_updates_tries >= MAX_FIRST_TOPOLOGY_UPDATES_TRIES
    end

    def prepare_command(command, server_node)
      request = command.create_request(server_node)

      @headers.each do |header, value|
        request.add_field(header, value)
      end

      unless @_without_topology
        request.add_field("Topology-Etag", @_topology_etag)
      end

      request
    end

    def disposed?
      @_disposed
    end

    def get_update_topology_command_class
      GetDatabaseTopologyCommand
    end

    def handle_server_down(_url, chosen_node, node_index, command, _request, _response, _e, session_info)
      command.add_failed_node(chosen_node)

      # We executed request over a node not in the topology. This means no failover...
      return false if node_index.nil?

      spawn_health_checks(chosen_node, node_index)
      return false if @_node_selector.nil?

      @_node_selector.on_failed_request(node_index)
      current_node, current_index = @_node_selector.preferred_node_and_index

      # we tried all the nodes...nothing left to do
      return false if command.failed_nodes.include?(current_node)

      execute(current_node, current_index, command, false, session_info)
      true
    end

    def spawn_health_checks(chosen_node, node_index)
      node_status = NodeStatus.new(node_index, chosen_node)
      if @_failed_nodes_timers.put_if_absent(chosen_node, node_status).nil?
        node_status.start_timer
      end
    end

    def check_node_status(node_status)
      nodes = @_node_selector.nodes
      index = node_status.node_index
      node = node_status.node

      return unless (index < nodes.size) && (node == nodes[index])

      perform_health_check(node)
    end

    def perform_health_check(server_node)
      if @_disposed
        return nil
      end

      is_still_failed = nil
      command = GetStatisticsCommand.new(check_for_failures: true)

      begin
        request = prepare_command(command, server_node)
        response = http_client(server_node).request(request)
        is_still_failed = !response.is_a?(Net::HTTPOK)

        unless is_still_failed
          emit(RavenServerEvent::NODE_STATUS_UPDATED, server_node)

          if @_failed_nodes_statuses.key?(server_node)
            @_failed_nodes_statuses[server_node].dispose
            @_failed_nodes_statuses.delete(server_node)
          end
        end
      rescue StandardError
        is_still_failed = true
      end

      return unless (is_still_failed == false) && @_failed_nodes_statuses.key?(server_node)

      @_failed_nodes_statuses[server_node].retry_update
    end

    def cancel_failing_nodes_timers
      @_failed_nodes_statuses.each_value { |status| status.dispose }
      @_failed_nodes_statuses.clear
    end

    def http_client(server_node)
      url = server_node.url
      uri = URI.parse(url)
      client = Net::HTTP.new(uri.host, uri.port)

      if uri.is_a?(URI::HTTPS)
        unless @_auth_options.is_a?(AuthOptions)
          raise NotSupportedException,
                "Access to secured servers requires RequestAuthOptions to be set"
        end

        client.use_ssl = true
        client.key = @_auth_options.rsa_key
        client.cert = @_auth_options.x509_certificate
      end

      client
    end
  end

  class ClusterRequestExecutor < RequestExecutor
    protected

    def get_update_topology_command_class
      GetClusterTopologyCommand
    end

    def update_topology_async(node:, timeout: nil, force_update: false)
      return Concurrent::Future.execute { false } if disposed?

      Concurrent::Future.execute do
        next false if disposed?

        command = GetClusterTopologyCommand.new
        execute(command, chosen_node: node)

        results = command.result
        nodes = results.topology.members.map do |key, value|
          server_node = ServerNode.new
          server_node.url = value
          server_node.cluster_tag = key
          server_node
        end
        new_topology = Topology.new
        new_topology.nodes = nodes
        if @_node_selector.nil?
          @_node_selector = NodeSelector.new(self, new_topology)
          # TODO
          # if @_read_balance_behavior == :fastest_node
          #   @_node_selector.schedule_speed_test
          # end
        elsif @_node_selector.on_update_topology(new_topology, force_update)
          # TODO: dispose_all_failed_nodes_timers
          # TODO
          # if @_read_balance_behavior == :fastest_node
          #  @_node_selector.schedule_speed_test
          # end
        end
        true
      end
    end
  end

  require_relative "../ravendb/utils/concurrent_hash_map.rb"
end
