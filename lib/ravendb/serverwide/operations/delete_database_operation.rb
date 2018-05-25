module RavenDB
  class DeleteDatabaseOperation < ServerOperation
    def initialize(database_name:, hard_delete: false, from_node: nil)
      super()

      @from_node = from_node
      @database_name = database_name
      @hard_delete = hard_delete

      if from_node.is_a?(ServerNode)
        @from_node = from_node.cluster_tag
      end
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      DeleteDatabaseCommand.new(@database_name, @hard_delete, @from_node)
    end
  end
end
