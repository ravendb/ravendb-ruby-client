module RavenDB
  class DeleteIndexOperation < AdminOperation
    def initialize(index_name)
      super()
      @index_name = index_name
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      DeleteIndexCommand.new(@index_name)
    end
  end
end
