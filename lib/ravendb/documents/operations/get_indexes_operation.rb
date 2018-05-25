module RavenDB
  class GetIndexesOperation < AdminOperation
    def initialize(start = 0, page_size = 10)
      super()
      @start = start
      @page_size = page_size
    end

    def get_command(_conventions)
      GetIndexesCommand.new(@start, @page_size)
    end
  end
end
