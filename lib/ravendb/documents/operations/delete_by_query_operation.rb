module RavenDB
  class DeleteByQueryOperation < QueryBasedOperation
    def get_command(conventions:, store: nil, http_cache: nil)
      DeleteByQueryCommand.new(@query, @options)
    end
  end
end
