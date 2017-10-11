require 'thread'
require 'database/exceptions'
require 'constants/documents'

module RavenDB
  class ServerNode
    attr_reader :url, :database, :cluster_tag

    def initialize(url = '', database = nil, cluster_tag = nil)
      @url = url
      @database = database
      @cluster_tag = cluster_tag
    end  

    def self.from_json(json)      
      node = self.new
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

  class DatabaseDocument
    attr_reader :database_id, :settings

    def initialize(database_id, settings = {}, secured_settings = {}, disabled = false, encrypted = false) 
      @database_id = database_id || nil
      @settings = settings
      @secured_settings = secured_settings
      @disabled = disabled
      @encrypted = encrypted
    end

    def to_json
      return {
        "DatabaseName" => @database_id,
        "Disabled" => @disabled,
        "Encrypted" => @encrypted,
        "SecuredSettings" => @secured_settings,
        "Settings" => @settings
      }
    end
  end

  class Topology    
    attr_reader :etag, :nodes

    def initialize(etag = 0, nodes = [])
      @etag = etag
      @nodes = nodes
    end

    def self.from_json(json)
      topology = self.new

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
        json["Topology"]["AllNodes"].each do |tag,url| 
          nodes.push({"Url" => url, "ClusterTag" => tag})
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
    MaxTimerPeriod = 60 * 5 * 1000
    TimerPeriodStep = 0.1 * 1000

    attr_reader :node_index, :node

    def initialize(node_index, node, &on_update)
      @_timer_period = 0
      @_timer = nil
      @_on_update = on_update
      @node_index = node_index
      @node = node
    end

    def next_timer_period
      max_period = MaxTimerPeriod

      if @_timer_period < max_period
        @_timer_period += TimerPeriodStep
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
      if @_timer
        @_timer.exit
      end
    end
  end

  class PatchRequest
    attr_reader :script

    def initialize(script, values = nil)
      @values = {}
      @script = script || nil

      if values
        @values = values
      end
    end

    def to_json
      return {
        "Script" => @script,
        "Values" => @values
      }
    end
  end

  class NodeSelector
    attr_reader :current_node_index

    def initialize(request_executor, topology)
      @current_node_index = 0
      @topology = topology
      @_lock = Mutex.new

      request_executor.on(RavenServerEvent::TOPOLOGY_UPDATED) { |data|
        on_topology_updated(data)
      }

      request_executor.on(RavenServerEvent::REQUEST_FAILED) { |data|
        on_request_failed(data)
      }

      request_executor.on(RavenServerEvent::NODE_STATUS_UPDATED) { |data|
        on_node_restored(data)
      }
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

    protected 
    def assign_topology(topology, force_update)
      old_topology = @topology
      
      @_lock.synchronize do
        if !force_update
          @current_node_index = 0
        end  

        if old_topology == topology
          @topology = topology
        elsif 
          assign_topology(topology, force_update)  
        end  
      end
    end

    def on_topology_updated(topology_data)
      should_update = false
      force_update = (true == topology_data["force_update"])

      if topology_data["topology_json"]
        topology = Topology.from_json(topology_data["topology_json"])

        if !topology.nodes.empty?
          should_update = force_update || (@topology.etag < topology.etag)
        end

        if should_update
          assign_topology(topology, force_update)
        end
      end

      topology_data["was_updated"] = should_update
    end

    def on_request_failed(failed_node)
      assert_topology
      @current_node_index = (@current_node_index + 1) % @topology.nodes.length
    end

    def on_node_restored(failed_node)
      nodes = @topology.nodes

      if nodes.include?(failed_node)
        failed_node_index = nodes.index(failed_node)
        
        if @current_node_index > failed_node_index
          @current_node_index = failed_node_index
        end
      end
    end

    def assert_topology
      if !@topology || !@topology.nodes || @topology.nodes.empty?
        raise InvalidOperationException, "Empty database topology, this shouldn't happen."
      end
    end
  end
end 