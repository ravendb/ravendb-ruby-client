require "database/commands"

module RavenDB
  class GetNextOperationIdCommand < RavenCommand
    def initialize
      super(nil)
    end

    def create_request(server_node, url: nil)
      @end_point = "/databases/" + server_node.database + "/operations/next-operation-id"
      assert_node(server_node)

      if url
        url.value = @end_point
        request = Net::HTTP::Get.new(url.value)
        request
      end
    end

    def set_response(response)
      response = super(response)

      raise_invalid_response! unless response.is_a?(Hash)

      if response.key?("Id")
        response["Id"]
      end
    end

    def read_request?
      false # disable caching
    end
  end
end
