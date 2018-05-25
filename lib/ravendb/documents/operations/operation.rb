module RavenDB
  class Operation < AbstractOperation
    def get_command(conventions:, store: nil, http_cache: nil)
      raise NotImplementedError, "You should implement get_command method"
    end
  end
end
