module RavenDB
  class PutDocumentCommand < RavenCommand
    def initialize(id:, document:, change_vector: nil)
      super("", Net::HTTP::Put::METHOD)

      @id = id
      @change_vector = change_vector
      @document = document
    end

    def create_request(server_node)
      raise "Document must be an object" unless @document

      @payload = @document
      assert_node(server_node)

      raise "Id must be a string" unless @id.is_a?(String)

      if @change_vector
        @headers = {"If-Match" => "\"#{@change_vector}\""}
      end

      @params = {"id" => @id}
      @end_point = "/databases/#{server_node.database}/docs"
    end

    def set_response(response)
      check_response(response)
      super(response)

      @mapper.read_value(response, PutResult)
    end

    protected

    def check_response(response)
      return if response.body

      raise ErrorResponseException, "Failed to store document to the database "\
        "please check the connection to the server"
    end
  end

  class PutResult
    attr_accessor :id
    attr_accessor :change_vector
  end
end
