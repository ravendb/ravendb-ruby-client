module RavenDB
  class DeleteByQueryOperation < QueryBasedOperation
    def get_command(_conventions, _store = nil)
      DeleteByQueryCommand.new(@query, @options)
    end
  end
end
