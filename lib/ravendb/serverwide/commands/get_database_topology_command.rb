require "database/commands"

module RavenDB
  class GetDatabaseTopologyCommand < RavenCommandUnified
    def create_request(server_node)
      assert_node(server_node)

      end_point = "/topology?name=#{server_node.database}"

      if server_node.url.downcase.include?(".fiddler")
        # we want to keep the '.fiddler' stuff there so we'll keep tracking request
        # so we are going to ask the server to respect it
        end_point += "&localUrl=" + CGI.escape(node.url)
      end

      Net::HTTP::Get.new(end_point)
    end

    def parse_response(json, from_cache:, conventions: nil)
      Topology.from_json(json)
    end

    def read_request?
      true
    end
  end
end
