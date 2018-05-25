module RavenDB
  class Operation < AbstractOperation
    def get_command(_conventions, _store = nil)
      raise NotImplementedError, "You should implement get_command method"
    end
  end
end
