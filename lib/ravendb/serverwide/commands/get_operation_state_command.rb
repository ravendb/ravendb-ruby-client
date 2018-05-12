module RavenDB
  class GetOperationStateCommand < RavenCommand
    def initialize(id)
      super("", Net::HTTP::Get::METHOD)
      @id = id
    end

    def create_request(server_node)
      assert_node(server_node)
      @params = {"id" => @id}
      @end_point = "/databases/#{server_node.database}/operations/state"
    end

    def set_response(response)
      result = super(response)

      if response.body
        return result
      end

      raise ErrorResponseException, "Invalid server response"
    end
  end
end
