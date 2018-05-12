module RavenDB
  class CreateDatabaseCommand < RavenCommand
    def initialize(database_document, replication_factor = 1)
      super("", Net::HTTP::Put::METHOD)
      @database_document = database_document
      @replication_factor = replication_factor || 1
    end

    def create_request(server_node)
      db_name = @database_document.database_id.gsub("Raven/Databases/", "")
      assert_node(server_node)

      @params = {"name" => db_name, "replicationFactor" => @replication_factor}
      @end_point = "/admin/databases"
      @payload = @database_document.to_json
    end

    def set_response(response)
      result = super(response)

      unless response.body
        raise ErrorResponseException, "Response is invalid."
      end

      result
    end
  end
end
