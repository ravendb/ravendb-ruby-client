module RavenDB
  class GetNextOperationIdCommand < RavenCommandUnified
    def create_request(server_node)
      assert_node(server_node)

      end_point = "/databases/#{server_node.database}/operations/next-operation-id"
      Net::HTTP::Get.new(end_point)
    end

    def parse_response(json, from_cache:, conventions: nil)
      json["Id"]
    end

    def read_request?
      false # disable caching
    end
  end
end
