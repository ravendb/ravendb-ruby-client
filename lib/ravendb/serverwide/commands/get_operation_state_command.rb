module RavenDB
  class GetOperationStateCommand < RavenCommand
    def initialize(id)
      super()
      @id = id
    end

    def create_request(server_node)
      assert_node(server_node)
      end_point = "/databases/#{server_node.database}/operations/state?id=#{@id}"

      Net::HTTP::Get.new(end_point)
    end

    def set_response(response)
      result = super(response)

      if response.body
        return result
      end

      raise ErrorResponseException, "Invalid server response"
    end

    def read_request?
      true
    end
  end
end
