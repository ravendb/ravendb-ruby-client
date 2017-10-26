module RavenDB
  class DeleteByQueryOperation < QueryBasedOperation
    def get_command(conventions, store = nil)
      DeleteByQueryCommand.new(@query, @options)
    end
  end

  class PatchByQueryOperation < QueryBasedOperation
    def initialize(query_to_update, options = nil)
      super(query_to_update, options)
    end

    def get_command(conventions, store = nil)
      PatchByQueryCommand.new(@query, @options)
    end
  end
end