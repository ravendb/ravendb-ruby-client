module RavenDB
  class PatchByQueryOperation < QueryBasedOperation
    def initialize(query_to_update, options = nil)
      super(query_to_update, options)
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      PatchByQueryCommand.new(@query, @options)
    end
  end
end
