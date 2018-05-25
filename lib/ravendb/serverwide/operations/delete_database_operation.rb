module RavenDB
  class DeleteDatabaseOperation < ServerOperation
    def initialize(database_id, hard_delete = false, from_node = nil)
      super()

      @from_node = from_node
      @database_id = database_id
      @hard_delete = hard_delete || false

      if from_node.is_a?(ServerNode)
        @from_node = from_node.cluster_tag
      end
    end

    def get_command(_conventions)
      DeleteDatabaseCommand.new(@database_id, @hard_delete, @from_node)
    end
  end
end
