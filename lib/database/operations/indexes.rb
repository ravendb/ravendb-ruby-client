module RavenDB
  class DeleteIndexOperation < AdminOperation
    def initialize(index_name)
      super()
      @index_name = index_name
    end

    def get_command(conventions)
      DeleteIndexCommand.new(@index_name)
    end
  end

  class GetIndexesOperation < AdminOperation
    def initialize(start = 0, page_size = 10)
      super()
      @start = start
      @page_size = page_size
    end

    def get_command(conventions)
      GetIndexesCommand.new(@start, @page_size)
    end
  end

  class GetIndexOperation < AdminOperation
    def initialize(index_name)
      super()
      @index_name = index_name
    end

    def get_command(conventions)
      GetIndexCommand.new(@index_name)
    end
  end

  class PutIndexesOperation < AdminOperation
    def initialize(indexes_to_add, *more_indexes_to_add)
      indexes = indexes_to_add.is_a?(Array) ? indexes_to_add : [indexes_to_add]

      if more_indexes_to_add.is_a?(Array) && !more_indexes_to_add.empty?
        indexes = indexes.concat(more_indexes_to_add)
      end

      super()
      @indexes = indexes
    end

    def get_command(conventions)
      PutIndexesCommand.new(@indexes)
    end
  end
end
