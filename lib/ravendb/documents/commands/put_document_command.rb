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

      payload = @document
      assert_node(server_node)

      raise "Id must be a string" unless @id.is_a?(String)

      end_point = "/databases/#{server_node.database}/docs?id=#{@id}"

      request = Net::HTTP::Put.new(end_point, "Content-Type" => "application/json")

      if @change_vector
        request["If-Match"] = "\"#{@change_vector}\""
      end

      request.body = payload.to_json
      request
    end

    def parse_response(json, from_cache:, conventions: nil)
      @mapper.read_value(json, PutResult, conventions: conventions)
    end

    def read_request?
      false
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
