require "uri"
require "time"
require "thread"
require "net/http"
require "openssl"
require "constants/database"
require "constants/documents"
require "database/exceptions"
require "database/commands"
require "documents/conventions"
require "requests/request_helpers"
require "utilities/observable"
require "auth/auth_options"

module RavenDB
  class RequestExecutor
    include Observable

    MaxFirstTopologyUpdatesTries = 5
    attr_reader :initial_database

    def initialize(database, options = {})
      urls = options[:first_topology_update_urls] || []

      @headers = {
        "Accept" => "application/json",
        "Raven-Client-Version" => "4.0.0-beta",
      }

      @_disposed = false
      @initial_database = database
      @_http_clients = {}
      @_first_topology_updates_tries = 0
      @_last_known_urls = nil
      @_failed_nodes_statuses = {}
      @_first_topology_update = nil
      @_first_topology_update_exception = nil
      @_node_selector = nil
      @_without_topology = options[:without_topology] || false
      @_topology_etag = options[:topology_etag] || 0
      @_await_first_topology_lock = Mutex.new
      @_update_topology_lock = Mutex.new
      @_update_failed_node_timer_lock = Mutex.new
      @_auth_options = nil

      if options.key?(:auth_options)
        @_auth_options = options[:auth_options]

        unless @_auth_options.nil? || @_auth_options.is_a?(RequestAuthOptions)
          raise ArgumentError,
                "Invalid auth options provided"
        end
      end

      if !@_without_topology && !urls.empty?
        start_first_topology_update(urls)
      elsif (@_without_topology && options[:single_node_topology])
        @_node_selector = NodeSelector.new(self, options[:single_node_topology])
      end
    end

    def self.create(urls, database = nil, auth_options = nil)
      self.new(database,
               without_topology: false,
               first_topology_update_urls: urls.clone,
               auth_options: auth_options)
    end

    def self.create_for_single_node(url, database = nil, auth_options = nil)
      topology = Topology.new(-1, [ServerNode.new(url, database)])

      self.new(database,
               without_topology: true,
               single_node_topology: topology,
               topology_etag: -2,
               auth_options: auth_options)
    end

    def execute(command)
      await_first_topology_update
      selector = @_node_selector
      chosen_node = selector.current_node
      chosen_node_index = selector.current_node_index

      response, should_retry = execute_command(command, chosen_node)

      if should_retry
        response = handle_server_down(command, chosen_node, chosen_node_index)
      end

      response
    end

    def dispose
      unless @_disposed
        @_disposed = true
        cancel_failing_nodes_timers
      end
    end

    protected
    def is_first_topology_update_tries_expired?
      @_first_topology_updates_tries >= MaxFirstTopologyUpdatesTries
    end

    def await_first_topology_update()
      is_fulfilled = false
      first_topology_update = @_first_topology_update

      if @_without_topology
        return
      end

      @_await_first_topology_lock.synchronize do
        if first_topology_update.equal?(@_first_topology_update)
          is_fulfilled = true == first_topology_update

          if false == first_topology_update
            start_first_topology_update(@_last_known_urls)
          end
        end
      end

      unless is_fulfilled
        if @_first_topology_update_exception.is_a?(AuthorizationException)
          raise @_first_topology_update_exception
        elsif is_first_topology_update_tries_expired?
          raise DatabaseLoadFailureException, "Max topology update tries reached"
        elsif
          sleep 0.1
          await_first_topology_update
        end
      end
    end

    def prepare_command(command, server_node)
      command.create_request(server_node)
      request = command.to_request_options

      @headers.each do |header, value|
        request.add_field(header, value)
      end

      unless @_without_topology
        request.add_field("Topology-Etag", @_topology_etag)
      end

      request
    end

    def execute_command(command, server_node)
      if @_disposed
        return nil
      end

      unless command.is_a?(RavenCommand)
        raise "Not a valid command"
      end

      unless server_node.is_a?(ServerNode)
        raise "Not a valid server node"
      end

      response = nil
      command_response = nil
      request_exception = nil
      request = prepare_command(command, server_node)

      begin
        response = http_client(server_node).request(request)
      rescue OpenSSL::SSL::SSLError => ssl_exception
        request_exception = unauthorized_error(server_node, request, ssl_exception)
      rescue Net::OpenTimeout => timeout_exception
        request_exception = timeout_exception
      end

      unless response.nil?
        if [Net::HTTPRequestTimeOut, Net::HTTPBadGateway,
            Net::HTTPGatewayTimeOut, Net::HTTPServiceUnavailable
        ].any? { |response_type| response.is_a?(response_type) }
          message = "HTTP #{response.code}: #{response.message}"
          request_exception = UnsuccessfulRequestException.new(message)
        elsif response.is_a?(Net::HTTPForbidden)
          request_exception = unauthorized_error(server_node, request, response)
        else
          if response.is_a?(Net::HTTPNotFound)
            response.body = nil
          end

          if !@_without_topology && response.key?("Refresh-Topology")
            update_topology(server_node)
          end

          command_response = command.set_response(response)
        end
      end

      should_retry = !request_exception.nil?

      if should_retry && (command.was_failed? ||
        request_exception.is_a?(AuthorizationException)
      )
        raise request_exception
      end

      [command_response, should_retry]
    end

    def start_first_topology_update(urls = [])
      if is_first_topology_update_tries_expired?
        return
      end

      @_last_known_urls = urls
      @_first_topology_updates_tries = @_first_topology_updates_tries + 1
      @_first_topology_update = Thread.new do
        updated = false

         for url in urls do
           begin
             update_topology(ServerNode.new(url, @initial_database))
             @_first_topology_update_exception = nil
             updated = true
             break
           rescue AuthorizationException => exception
             @_first_topology_update_exception = exception
           rescue StandardError
             next
           end
         end

        @_first_topology_update = updated
      end
    end

    def update_topology(server_node)
      topology_command_class = get_update_topology_command_class

      @_update_topology_lock.synchronize do
        response, was_failed = execute_command(topology_command_class.new, server_node)

        if was_failed || response.nil?
          raise UnsuccessfulRequestException, "Unable to obtain topology from node #{server_node.url}"
        end

        if @_node_selector
          event_data = {
            topology_json: response,
            server_node_url: server_node.url,
            requested_database: server_node.database,
            force_update: false
          }

          emit(RavenServerEvent::TOPOLOGY_UPDATED, event_data)

          if event_data[:was_updated]
            cancel_failing_nodes_timers
          end
        else
          @_node_selector = NodeSelector.new(self, Topology.from_json(response))
        end

        @_topology_etag = @_node_selector.topology_etag
      end
    end

    def get_update_topology_command_class
      GetTopologyCommand
    end

    def handle_server_down(command, failed_node, failed_node_index)
      next_node = nil
      node_selector = @_node_selector

      command.add_failed_node(failed_node)

      @_update_failed_node_timer_lock.synchronize do
        status = NodeStatus.new(failed_node_index, failed_node) do |node_status|
          check_node_status(node_status)
        end

        @_failed_nodes_statuses[failed_node] = status
        status.start_update
      end

      emit(RavenServerEvent::REQUEST_FAILED, failed_node)
      next_node = node_selector.current_node

      if !next_node || command.was_failed_with_node?(next_node)
        raise AllTopologyNodesDownException, "Tried all nodes in the cluster "\
          "but failed getting a response"
      end

      execute_command(command, next_node).first
    end

    def check_node_status(node_status)
      nodes = @_node_selector.nodes
      index = node_status.node_index
      node = node_status.node

      if (index < nodes.size) && (node == nodes[index])
        perform_health_check(node)
      end
    end

    def perform_health_check(server_node)
      if @_disposed
        return nil
      end

      is_still_failed = nil
      command = GetStatisticsCommand.new(true)

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

      if (is_still_failed == false) && @_failed_nodes_statuses.key?(server_node)
        @_failed_nodes_statuses[server_node].retry_update()
      end
    end

    def cancel_failing_nodes_timers
      @_failed_nodes_statuses.each_value {|status| status.dispose}
      @_failed_nodes_statuses.clear
    end

    def http_client(server_node)
      url = server_node.url

      unless @_http_clients.key?(url)
        uri = URI.parse(url)
        client = Net::HTTP.new(uri.host, uri.port)

        if uri.is_a?(URI::HTTPS)
          unless @_auth_options.is_a?(RequestAuthOptions)
            raise NotSupportedException,
                  "Access to secured servers requires RequestAuthOptions to be set"
          end

          client.use_ssl = true
          client.key = @_auth_options.get_rsa_key
          client.cert = @_auth_options.get_x509_certificate
        end

        @_http_clients[url] = client
      end

      @_http_clients[url]
    end

    def unauthorized_error(server_node, request, response_or_exception = nil)
      message = nil
      ssl_exception = nil

      if !!server_node.database
        message = "database #{server_node.database} on "
      end

      message = "Forbidden access to #{message}#{server_node.url} node, "

      if @_auth_options.certificate.nil?
        message = "#{message}a certificate is required."
      else
        message = "#{message}certificate does not have permission to access it or is unknown."
      end

      if response_or_exception.is_a?(Exception)
        ssl_exception = response_or_exception.message
      elsif response_or_exception.is_a?(Net::HTTPResponse)
        body = response_or_exception.json(false)

        if !body.nil? && body.key?("Message")
          ssl_exception = body["Message"]
        end
      end

      unless ssl_exception.nil?
        message = "#{message} SSL Exception: #{ssl_exception}"
      end

      message = "#{message} #{request.method} #{request.path}"

      AuthorizationException.new(message)
    end
  end

  class ClusterRequestExecutor < RequestExecutor
    protected
    def get_update_topology_command_class
      GetClusterTopologyCommand
    end
  end
end