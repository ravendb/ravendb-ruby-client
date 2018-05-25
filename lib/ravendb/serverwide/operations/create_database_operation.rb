module RavenDB
  class CreateDatabaseOperation < ServerOperation
    def initialize(database_document, replication_factor = 1)
      super()
      @database_document = database_document
      @replication_factor = replication_factor || 1
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      CreateDatabaseCommand.new(@database_document, @replication_factor)
    end
  end
end
