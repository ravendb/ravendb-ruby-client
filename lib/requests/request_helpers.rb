require "database/exceptions"
require "constants/documents"

module RavenDB
  class ServerNode
    attr_accessor :url, :database, :cluster_tag

    def initialize(url = "", database = nil, cluster_tag = nil)
      @url = url
      @database = database
      @cluster_tag = cluster_tag
    end

    def self.from_json(json)
      node = new
      node.from_json(json)

      node
    end

    def from_json(json)
      raise ArgumentError, 'Argument "json" should be an hash object' unless json.is_a? Hash

      @url = json["Url"]
      @database = json["Database"]
      @cluster_tag = json["ClusterTag"]
    end
  end

  class Topology
    attr_accessor :etag, :nodes

    def initialize(etag = 0, nodes = [])
      @etag = etag
      @nodes = nodes
    end

    def self.from_json(json)
      topology = new

      topology.from_json(json)
      topology
    end

    def from_json(json)
      @nodes = []
      @etag = 0
      nodes = []

      if json["Etag"]
        @etag = json["Etag"]
      end

      if json["Topology"] && json["Topology"]["AllNodes"]
        json["Topology"]["AllNodes"].each do |tag, url|
          nodes.push("Url" => url, "ClusterTag" => tag)
        end
      elsif json["Nodes"]
        nodes = json["Nodes"]
      end

      nodes.each do |node|
        @nodes.push(ServerNode.from_json(node))
      end
    end
  end

  class NodeStatus
    MAX_TIMER_PERIOD = 60 * 5 * 1000
    TIMER_PERIOD_STEP = 0.1 * 1000

    attr_reader :node_index, :node

    def initialize(node_index, node, &on_update)
      @_timer_period = 0
      @_timer = nil
      @_on_update = on_update
      @node_index = node_index
      @node = node
    end

    def next_timer_period
      max_period = MAX_TIMER_PERIOD

      if @_timer_period < max_period
        @_timer_period += TIMER_PERIOD_STEP
      end

      [max_period, @_timer_period].min
    end

    def start_update
      dispose

      @_timer = Thread.new do
        sleep next_timer_period
        @_on_update.call(self)
        @_timer = nil
      end
    end

    def retry_update
      start_update
    end

    def dispose
      return unless @_timer

      @_timer.exit
      @_timer = nil
    end

    def start_timer
    end
  end

  class PatchRequest
    attr_reader :script

    def initialize(script, values = nil)
      @values = values || {}
      @script = script
    end

    def to_json
      {
        "Script" => @script,
        "Values" => @values
      }
    end
  end

  class NodeSelector
    attr_reader :current_node_index
    attr_reader :topology

    def initialize(request_executor, topology)
      @current_node_index = 0
      @topology = topology
      @_lock = Mutex.new
      @_state = NodeSelectorState.new(@current_node_index, topology)

      request_executor.on(RavenServerEvent::TOPOLOGY_UPDATED) do |data|
        on_topology_updated(data)
      end

      request_executor.on(RavenServerEvent::REQUEST_FAILED) do |data|
        on_request_failed(data)
      end

      request_executor.on(RavenServerEvent::NODE_STATUS_UPDATED) do |data|
        on_node_restored(data)
      end
    end

    def nodes
      assert_topology
      @topology.nodes
    end

    def topology_etag
      @topology.etag
    end

    def current_node
      nodes.at(@current_node_index)
    end

    def preferred_node
      current_node
    end

    def preferred_node_and_index
      [preferred_node, 0]
    end

    def on_failed_request(node_index)
      state = @_state

      # probably already changed
      return if (node_index < 0) || (node_index >= state.failures.length)

      state.failures[node_index].increment
    end

    protected

    def assign_topology(topology, force_update)
      old_topology = @topology

      @_lock.synchronize do
        unless force_update
          @current_node_index = 0
        end

        if old_topology == topology
          @topology = topology
        else
          assign_topology(topology, force_update)
        end
      end
    end

    def on_topology_updated(topology_data)
      should_update = false
      force_update = (topology_data[:force_update] == true)

      if topology_data[:topology_json]
        topology = Topology.from_json(topology_data[:topology_json])

        unless topology.nodes.empty?
          should_update = force_update || (@topology.etag < topology.etag)
        end

        if should_update
          assign_topology(topology, force_update)
        end
      end

      topology_data[:was_updated] = should_update
    end

    def on_request_failed(failed_node)
      assert_topology
      @current_node_index = (@current_node_index + 1) % @topology.nodes.length
    end

    def on_node_restored(failed_node)
      nodes = @topology.nodes

      return unless nodes.include?(failed_node)

      failed_node_index = nodes.index(failed_node)

      return unless @current_node_index > failed_node_index

      @current_node_index = failed_node_index
    end

    def assert_topology
      return unless !@topology || !@topology.nodes || @topology.nodes.empty?

      raise "Empty database topology, this shouldn't happen."
    end
  end

  class NodeSelectorState
    attr_accessor :topology
    attr_accessor :current_node_index
    attr_accessor :nodes
    attr_accessor :failures
    attr_accessor :fastest_records
    attr_accessor :fastest
    attr_accessor :speed_test_mode

    def initialize(current_node_index, topology)
      self.topology = topology
      self.current_node_index = current_node_index
      self.nodes = topology.nodes
      self.failures = Array.new(topology.nodes.count) { Concurrent::AtomicFixnum.new(0) }
      self.fastest_records = Array.new(topology.nodes.count) { 0 }
      self.speed_test_mode = Concurrent::AtomicFixnum.new(0)
    end
  end
end
