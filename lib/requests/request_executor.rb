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
  @_first_topology_update = nil

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

  def execute(command)
    chosen_node = nil
    chosen_node_index = -1

    await_first_topology_update
    selector = @_nodeSelector;
    chosen_node = selector.current_node;
    chosen_node_index = selector.current_node_index;

    begin
      response = execute_command(command, chosen_node)
    rescue TopologyNodeDownException
      response = handle_server_down(command, chosen_node, chosen_node_index)
    end

    return response
  end  

  protected
  def await_first_topology_update()
    is_fulfilled = false
    first_topology_update = @_first_topology_update

    if @_without_topology
      return
    end

    @_await_first_topology_lock.syncronize do
      if first_topology_update.equal?(@_first_topology_update)
        is_fulfilled = true === first_topology_update;

        if false === first_topology_update
          start_first_topology_update(@_last_known_urls)
        end  
      end
    end  

    if !is_fulfilled
      if is_first_topology_update_tries_expired
        raise DatabaseLoadFailureException, 'Max topology update tries reached'
      elsif
        sleep .1
        await_first_topology_update
      end    
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
    
    begin
      response = Net::HTTP.request(request)
    rescue
      raise TopologyNodeDownException, "Node #{server_node.url} is down"
    end    

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
    @_first_topology_update = Thread.new do
      for url in urls do
        update_topology(ServerNode.new(url, @_initial_database))
        @_first_topology_update = true
        break
      rescue
        next
      end  

      @_first_topology_update = false 
    end    

    @_first_topology_update.join
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
  def handle_server_down(command, failed_node, failed_node_index)
    next_node = nil
    node_selector = @_node_selector
    REQUEST_FAILED  = RavenServerEvent::REQUEST_FAILED

    command.add_failed_node(failed_node)

    @_update_failed_node_timer_lock.syncronize do
      status = NodeStatus.new(failed_node_index, failed_node, {
        |status| check_node_status(status)
      })

      @_failed_nodes_statuses[failed_node] = status
      status.start_update
    end  

    emit(REQUEST_FAILED, failed_node)
    next_node = node_selector.current_node

    if !next_node || command.was_failed_with_node(next_node)
      raise AllTopologyNodesDownException, "Tried all nodes in the cluster "\
        "but failed getting a response"
    end  

    return execute_command(command, next_node)
  end  

  protected 
  def check_node_status(node_status)
    nodes = @_node_selector.nodes
    index = node_status.node_index
    node = node_status.node

    if (index < nodes.size) && (node === nodes[index])
      perform_health_check(node)
    end
  end

  protected perform_health_check(server_node)
    status = nil
    is_still_failed = nil
    command = GetStatisticsCommand.new(true)
    NODE_STATUS_UPDATED = RavenServerEvent::NODE_STATUS_UPDATED    
        
    begin
      response = Net::HTTP.request(prepare_command(command, server_node))
      is_still_failed = response.is_a?(Net::HTTPOK)

      if is_still_failed == true
        emit(NODE_STATUS_UPDATED, server_node)

        if @_failed_nodes_statuses.key?(server_node)
          @_failed_nodes_statuses[server_node].dispose

        end  
      end  
    rescue
      is_still_failed = false
    end    

    if isStillFailed && @_failed_nodes_statuses.key?(server_node)
      @_failed_nodes_statuses[server_node].retry_update()
      @_failed_nodes_statuses.delete(server_node)
    end
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