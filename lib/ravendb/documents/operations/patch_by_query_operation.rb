module RavenDB
  class PatchByQueryOperation < QueryBasedOperation
    def initialize(query_to_update, options = nil)
      super(query_to_update, options)
    end

    def get_command(_conventions, _store = nil)
      PatchByQueryCommand.new(@query, @options)
    end
  end
end
