module RavenDB
  class DeleteDocumentCommand < RavenCommand
    def initialize(id, change_vector = nil)
      super()

      @id = id
      @change_vector = change_vector
    end

    def create_request(server_node)
      assert_node(server_node)

      raise "Nil Id is not valid" unless @id
      raise "Id must be a string" unless @id.is_a?(String)

      end_point = "/databases/#{server_node.database}/docs?id=#{@id}"

      request = Net::HTTP::Delete.new(end_point, "Content-Type" => "application/json")

      if @change_vector
        request["If-Match"] = "\"#{@change_vector}\""
      end

      request
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
