module RavenDB
  class AbstractOperation
    def get_command(_conventions)
      raise NotImplementedError, "You should implement get_command method"
    end
  end
end
