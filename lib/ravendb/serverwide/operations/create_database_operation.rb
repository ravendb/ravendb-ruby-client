module RavenDB
  class CreateDatabaseOperation < ServerOperation
    def initialize(database_record:, replication_factor: 1)
      super()
      @database_record = database_record
      @replication_factor = replication_factor
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      CreateDatabaseCommand.new(@database_record, @replication_factor)
    end
  end
end
