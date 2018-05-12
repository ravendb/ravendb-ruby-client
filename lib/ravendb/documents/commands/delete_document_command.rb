module RavenDB
  class DeleteDocumentCommand < RavenCommand
    def initialize(id, change_vector = nil)
      super("", Net::HTTP::Delete::METHOD)

      @id = id
      @change_vector = change_vector
    end

    def create_request(server_node)
      assert_node(server_node)

      unless @id
        raise "Nil Id is not valid"
      end

      unless @id.is_a?(String)
        raise "Id must be a string"
      end

      if @change_vector
        @headers = {"If-Match" => "\"#{@change_vector}\""}
      end

      @params = {"id" => @id}
      @end_point = "/databases/#{server_node.database}/docs"
    end

    def set_response(response)
      super(response)
      check_response(response)
    end

    protected

    def check_response(response)
      return if response.is_a?(Net::HTTPNoContent)

      raise "Could not delete document #{@id}"
    end
  end
end
