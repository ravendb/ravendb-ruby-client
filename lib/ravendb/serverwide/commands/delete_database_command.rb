module RavenDB
  class DeleteDatabaseCommand < RavenCommand
    def initialize(database_name, hard_delete = false, from_node = nil, time_to_wait_for_confirmation = nil)
      super()

      @database_name = database_name
      @from_node = from_node
      @hard_delete = hard_delete || false
      @time_to_wait_for_confirmation = time_to_wait_for_confirmation

      @from_node = from_node.cluster_tag if @from_node.is_a?(ServerNode)
    end

    def create_request(_server_node)
      db_name = @database_name.gsub("Raven/Databases/", "")
      end_point = "/admin/databases"

      payload = {
        "DatabaseNames" => [db_name],
        "HardDelete" => @hard_delete,
        "TimeToWaitForConfirmation" => @time_to_wait_for_confirmation
      }
      payload["FromNodes"] = [@from_node] if @from_node

      request = Net::HTTP::Delete.new(end_point, "Content-Type" => "application/json")
      request.body = payload.to_json
      request
    end
  end
end
