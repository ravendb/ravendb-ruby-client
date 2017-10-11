module RavenDB
  class DeleteByQueryOperation < QueryBasedOperation
    def get_command(conventions, store = nil)
      DeleteByQueryCommand.new(@query, @options)
    end
  end

  class PatchByQueryOperation < QueryBasedOperation
    def initialize(query_to_update, patch = nil, options = nil)
      super(query_to_update, options)
      @patch = patch
    end

    def get_command(conventions, store = nil)
      PatchByQueryCommand.new(@query, @patch, @options)
    end
  end
end