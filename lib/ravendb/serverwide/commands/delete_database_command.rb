module RavenDB
  class DeleteDatabaseCommand < RavenCommand
    def initialize(database_id, hard_delete = false, from_node = nil, time_to_wait_for_confirmation = nil)
      super("", Net::HTTP::Delete::METHOD)

      @database_id = database_id
      @from_node = from_node
      @hard_delete = hard_delete || false
      @time_to_wait_for_confirmation = time_to_wait_for_confirmation

      @from_node = from_node.cluster_tag if @from_node.is_a?(ServerNode)
    end

    def create_request(server_node)
      db_name = @database_id.gsub("Raven/Databases/", "")
      @end_point = "/admin/databases"

      @payload = {
          "DatabaseNames" => [db_name],
          "HardDelete" => @hard_delete,
          "TimeToWaitForConfirmation" => @time_to_wait_for_confirmation
      }

      @payload["FromNodes"] = [@from_node] if @from_node
    end
  end
end
