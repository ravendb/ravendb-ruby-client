module RavenDB
  class GetDatabaseNamesOperation < ServerOperation
    def initialize(start:, page_size:)
      @start = start
      @page_size = page_size
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      RavenDB::GetDatabaseNamesCommand.new(start: @start, page_size: @page_size)
    end
  end
end
