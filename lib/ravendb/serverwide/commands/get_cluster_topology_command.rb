module RavenDB
  class GetClusterTopologyCommand < RavenCommand
    def initialize(force_url = nil)
      super()
      @force_url = force_url
    end

    def create_request(server_node)
      assert_node(server_node)

      end_point = "/cluster/topology"
      end_point += "?url=#{@force_url}" if @force_url
      Net::HTTP::Get.new(end_point)
    end

    def read_request?
      true
    end

    def parse_response(json, from_cache:, conventions: nil)
      ClusterTopologyResponse.from_json(json)
    end
  end

  class ClusterTopologyResponse
    attr_accessor :leader
    attr_accessor :node_tag
    attr_accessor :topology

    def self.from_json(json)
      response = new
      response.leader = json["Leader"]
      response.node_tag = json["NodeTag"]
      response.topology = ClusterTopology.from_json(json["Topology"])
      response
    end
  end

  class ClusterTopology
    attr_accessor :last_node_id
    attr_accessor :topology_id
    attr_accessor :members
    attr_accessor :promotables
    attr_accessor :watchers

    def self.from_json(json)
      response = new
      response.last_node_id = json["LastNodeId"]
      response.topology_id = json["TopologyId"]
      response.members = json["Members"]
      response.promotables = json["Promotables"]
      response.watchers = json["Watchers"]
      response
    end
  end
end
