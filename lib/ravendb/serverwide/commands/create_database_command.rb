module RavenDB
  class CreateDatabaseCommand < RavenCommand
    def initialize(database_record, replication_factor = 1)
      super()
      @database_record = database_record
      @replication_factor = replication_factor
    end

    def create_request(server_node)
      assert_node(server_node)

      db_name = @database_record.database_id.gsub("Raven/Databases/", "")
      end_point = "/admin/databases?name=#{db_name}&replicationFactor=#{@replication_factor}"
      payload = @database_record.to_json

      request = Net::HTTP::Put.new(end_point, "Content-Type" => "application/json")
      request.body = payload.to_json
      request
    end

    def set_response(response)
      result = super(response)

      raise ErrorResponseException, "Response is invalid." unless response.body

      result
    end

    def read_request?
      false
    end
  end
end
