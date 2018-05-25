module RavenDB
  class DeleteIndexOperation < AdminOperation
    def initialize(index_name)
      super()
      @index_name = index_name
    end

    def get_command(_conventions)
      DeleteIndexCommand.new(@index_name)
    end
  end
end
