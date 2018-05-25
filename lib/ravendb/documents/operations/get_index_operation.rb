module RavenDB
  class GetIndexOperation < AdminOperation
    def initialize(index_name)
      super()
      @index_name = index_name
    end

    def get_command(_conventions)
      GetIndexCommand.new(@index_name)
    end
  end
end
