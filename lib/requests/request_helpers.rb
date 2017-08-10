require 'thread'
require 'database/exceptions'
require 'contsants/documents'

module RavenDB
  class ServerNode
    @url = ''
    @database = nil
    @cluster_tag = nil

    def self.from_json(json)      
      node = self.new
      node.from_json(json)

      return node
    end

    def url
      @url
    end

    def database
      @database
    end

    def cluster_tag
      @cluster_tag
    end

    def initialize(url = '', database = nil, cluster_tag = nil)
      @url = url
      @database = database
      @cluster_tag = cluster_tag
    end  

    def from_json(json)     
      raise ArgumentError, 'Argument "json" should be an hash object' unless json.is_a? Hash
      
      @url = json["Url"]
      @database = json["Database"]
      @cluster_tag = json["ClusterTag"]
    end
  end

  class DatabaseDocument
    @secureSettings = {}
    @disabled = false
    @encrypted = false;
    @_databaseId = nil;
    @_settings = {};

    def initialize(databaseId, settings = {}, secureSettings = {}, disabled = false, encrypted = false) 
      @_databaseId = databaseId;
      @_settings = settings;
      @secureSettings = secureSettings;
      @disabled = disabled;
      @encrypted = encrypted;
    end

    def database_id()
      @_databaseId
    end

    def settings
      @_settings
    end

    def to_json
      return {
        "DatabaseName" => @_databaseId,
        "Disabled" => @disabled,
        "Encrypted" => @encrypted,
        "SecuredSettings" => @secureSettings,
        "Settings" => @_settings
      }
    end
  end

  class Topology
    @_etag = 0
    @_nodes = nil

    def self.from_json(json)
      topology = self.new

      topology.fromJson(json)
      return topology;
    end

    def initialize(etag = 0, nodes = []) {
      @_etag = etag
      @_nodes = nodes;
    }

    def nodes
      @_nodes
    end

    def etag
      @_etag
    end

    def from_json(json)
      @_nodes = []
      @_etag = 0
      nodes = []

      if json.Etag
        @_etag = json.Etag
      end  

      if json.Topology && json.Topology.AllNodes
        json.Topology.AllNodes.each do |tag,url| 
          nodes.insert({"Url" => url, "ClusterTag" => tag})
        end
      elsif json.Nodes
        nodes = json.Nodes;
      end

      nodes.each do |node|
         @_nodes.insert(ServerNode.fromJson(node))
      end   
    end
  end

  class NodeStatus
    MaxTimerPeriod = 60 * 5 * 1000;
    TimerPeriodStep = .1 * 1000;
    
    @_node_index = nil
    @_node = nil
    @_timer_period = 0
    @_timer = nil
    @_on_update = nil

    def next_timer_period
      max_period = MaxTimerPeriod;

      if @_timer_period < max_period
        @_timer_period += TimerPeriodStep;
      end

      return [max_period, @_timer_period].min
    end

    def node_index
      @_nodeIndex
    end

    def node
      @_node
    end

    def initialize(node_index, node, on_update)
      @_on_update = onUpdate
      @_node_index = node_index
      @_node = node
    end

    def start_update
      dispose

      @_timer = Thread.new do
        sleep next_timer_period
        @_on_update.call(self)
        @_timer = nil
      end  

      @_timer.join
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
    @_script = nil
    @values = {}

    def initialize(script, values = nil) {
      @_script = script

      if (values) {
        @values = values
      }
    }

    def script
      @_script
    end

    def to_json
      return {
        "Script" => @_script,
        "Values" => @values
      }
    end
  end

  class NodeSelector
    @_current_node_index = 0
    @initial_database = nil
    @topology = nil
    @_lock = nil

    def nodes
      assert_topology
      return @topology.nodes
    end

    def current_node_index
      @_current_node_index
    end

    def topology_etag
      return @topology.etag
    end

    def current_node
      return @nodes.at(@_current_node_index)
    end

    def initialize(request_executor, topology) {
      @topology = topology
      @_lock = Mutex.new

      request_executor.on(RavenServerEvent.TOPOLOGY_UPDATED, { |data|
        on_topology_updated(data)
      })

      request_executor.on(RavenServerEvent.REQUEST_FAILED, { |data|
        on_request_failed(data)
      })

      request_executor.on(RavenServerEvent.NODE_STATUS_UPDATED, { |data|
        on_node_restored(data)
      })
    end

    protected 
    def assign_topology(topology, force_update)
      old_topology = @topology
      
      (Thread.new { @_lock.syncronize do
        if !force_update
          @_current_node_index = 0
        end  

        if old_topology == topology
          @topology = topology;
        elsif 
          assign_topology(topology, force_update)  
        end  
      end }).join
    }

    protected 
    def on_topology_updated(topology_data)
      should_update = false
      force_update = (true === topology_data["force_update"])

      if topology_data["topology_json"]
        topology = Topology.fromJson(topology_data["topology_json"])

        if !topology.nodes.empty?
          should_update = force_update || (@topology.etag < topology.etag)
        end

        if should_update
          assign_topology(topology, force_update);
        end
      end

      topology_data["was_updated"] = shouldUpdate
    end

    protected
    def on_request_failed(failed_node)
      assert_topology
      @_currentNodeIndex = (++@_currentNodeIndex) % @topology.nodes.length
    end

    protected
    def on_node_restored(failed_node)
      nodes = @topology.nodes

      if nodes.include?(failed_node)
        failed_node_index = nodes.index(failed_node)
        
        if @_currentNodeIndex > failedNodeIndex
          @_currentNodeIndex = failedNodeIndex
        end
      end
    end

    protected 
    def assert_topology
      if !@topology || !@topology.nodes || @topology.nodes.empty?
        raise InvalidOperationException, "Empty database topology, this shouldn't happen."
      end
    end
  end
end 