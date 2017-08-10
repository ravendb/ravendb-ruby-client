require 'time'
require 'thread'
require 'constants/database'
require 'constants/documents'
require 'database/exceptions'
require 'database/commands'
require 'documents/conventions'
require 'request/request_helpers'
require 'utilities/observable'

class RequestExecutor
  MaxFirstTopologyUpdatesTries = 5
  
  include Observable

  @headers = {}
  @_first_topology_updates_tries = 0
  @_without_topology = false
  @_node_selector = nil
  @_last_known_urls = nil
  @_initial_database = nil
  @_topology_etag = 0
  @_failed_nodes_statuses = {}
  @_await_first_topology_lock = nil
  @_update_topology_lock = nil
  @_update_failed_node_timer_lock = nil
  @_first_topology_update_thread = nil

  def initial_database
    @_initialDatabase
  end

  def self.create(urls, database = nil)
    return self.new(database, {
      "without_topology" => false,
      "first_topology_update_urls" => urls.clone
    })
  end

  def self.create_for_single_node(url, database = nil)
    topology = Topology.new(-1, [ServerNode.new(url, database)])

    return self.new(database, {
      "without_topology" => true,
      "single_node_topology" => topology,
      "topology_etag" => -2
    })
  end

  def initialize(database, options = {})
    urls = options["first_topology_update_urls"] || []

    @headers = {
      "Accept" => "application/json",
      "Raven-Client-Version" => "4.0.0-beta",
    }

    @_last_known_urls = null
    @_initial_database = database
    @_without_topology = options["without_topology"] || false
    @_topology_etag = options["topology_etag"] || 0    
    @_await_first_topology_lock = Mutex.new
    @_update_topology_lock = Mutex.new
    @_update_failed_node_timer_lock = Mutex.new

    if !@_withoutTopology && !urls.empty?
      start_first_topology_update(urls)
    elsif (@_withoutTopology && options["single_node_topology"]) {
      @_node_selector = NodeSelector.new(self, options["single_node_topology"])
    end
  end

  protected
  def prepare_command(command, server_node)
    command.create_request(server_node)
    request = command.to_request_options

    @headers.each do |header, value|
      request.add_field(header, value)
    end

    if !@_without_topology
      request.add_field("Topology-Etag", @_topology_etag)
    end

    return request
  end

  protected 
  def execute_command(command, server_node)
    if !command.is_a?(RavenCommand)
      raise InvalidOperationException, 'Not a valid command'
    end

    if !command.is_a?(ServerNode)
      raise InvalidOperationException, 'Not a valid server node'
    end

    request = prepare_command(command, node)
    #TODO: handle server down & raise TopologyNodeDownException
    response = Net::HTTP.request(request)
    is_server_error = [Net::HTTPRequestTimeout, Net::HTTPBadGateway,
      Net:HTTPGatewayTimeout, Net::HTTPServiceUnavailable].any? { 
      | response_type | response.is_a?(response_type)
    }

    if response.is_a?(Net::HTTPNotFound)
      response.body = nil
    end  

    if is_server_error
      if command.was_failed
        message = 'Unsuccessfull request'
        json = response.json

        if json && json.Error
            message += ": #{json.Error}";
        end

        raise UnsuccessfulRequestException, message
      end

      raise TopologyNodeDownException, "Node #{server_node.url} is down"
    end
    
    if !@_without_topology && response.key?("Refresh-Topology")
      update_topology(server_node)
    end
    
    return command.set_response(response)
  end

  protected
  def start_first_topology_update(urls = [])
    if is_first_topology_update_tries_expired
      return
    end  

    @_last_known_urls = urls  
    @_first_topology_updates_tries++
    @_first_topology_update_thread = Thread.new do
      for url in urls do
        update_topology(ServerNode.new(url, @_initial_database))
        @_first_topology_update_thread = nil
        break
      rescue
        next
      end  
    end    
  end

  protected
  def is_first_topology_update_tries_expired
    return @_first_topology_updates_tries >= MaxFirstTopologyUpdatesTries
  end

  protected 
  def update_topology(server_node)
    TOPOLOGY_UPDATED = RavenServerEvent::TOPOLOGY_UPDATED
    topology_command_class = get_update_topology_command_class

    @_update_topology_lock.syncronize do
      response = execute_command(topology_command_class.new, server_node)

      if @_node_selector
        event_data = {
          "topology_json" => response,
          "server_node_url" => server_node.url,
          "requested_database" => server_node.database,
          "force_update" => false
        }

        emit(TOPOLOGY_UPDATED, event_data);

        if event_data["was_updated"]
          cancel_failing_nodes_timers
        end
      elsif
        @_node_selector = NodeSelector.new(self, Topology.fromJson(response))
      end    

      @_topology_etag = @_node_selector.topology_etag
    end  
  end

  protected
  def get_update_topology_command_class
    return GetTopologyCommand.class
  end  

  protected
  def cancel_failing_nodes_timers
    @_failed_nodes_statuses.each_value({ |status| status.dispose }) 
    @_failed_nodes_statuses.clear
  end  
end  

class ClusterRequestExecutor < RequestExecutor
  protected
  def get_update_topology_command_class
    return GetClusterTopologyCommand.class
  end  
end