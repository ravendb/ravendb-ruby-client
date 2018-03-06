module RavenDB
  class CreateDatabaseOperation < ServerOperation
    def initialize(database_document, replication_factor = 1)
      super()
      @database_document = database_document || nil
      @replication_factor = replication_factor || 1
    end

    def get_command(conventions)
      CreateDatabaseCommand.new(@database_document, @replication_factor)
    end
  end

  class DeleteDatabaseOperation < ServerOperation
    def initialize(database_id, hard_delete = false, from_node = nil)
      super()

      @from_node = from_node || nil
      @database_id = database_id || nil
      @hard_delete = hard_delete || false

      if from_node.is_a?(ServerNode)
        @from_node = from_node.cluster_tag
      end
    end

    def get_command(conventions)
      DeleteDatabaseCommand.new(@database_id, @hard_delete, @from_node)
    end
  end

  class GetStatisticsOperation < AdminOperation
    def get_command(conventions)
      GetStatisticsCommand.new
    end
  end

  class PatchOperation < PatchResultOperation
    attr_reader :id

    def initialize(id, patch, options = nil)
      super()
      @id = id
      @patch = patch
      @options = options
    end

    def get_command(conventions, store = nil)
      PatchCommand.new(@id, @patch, @options)
    end
  end
end
