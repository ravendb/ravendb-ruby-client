require 'database/auth'
require 'database/exceptions'
require 'database/commands'
require 'documents/document_query'
require 'requests/request_helpers'

module RavenDB
  class AbstractOperation
    def get_command(conventions)
      raise NotImplementedError, 'You should implement get_command method'
    end
  end

  class Operation < AbstractOperation
    def get_command(conventions, store = nil)
      raise NotImplementedError, 'You should implement get_command method'
    end
  end

  class AdminOperation < AbstractOperation
  end  

  class ServerOperation < AbstractOperation
  end  

  class PatchResultOperation < Operation 
  end  

  class AwaitableOperation < Operation
  end  

  class IndexQueryBasedOperation < AwaitableOperation
    def initialize(query, options = nil)
      super()
      @query = query || nil
      @options = options || QueryOperationOptions.new
    end
  end

  class CreateDatabaseOperation < ServerOperation
    def initialize(database_document, replication_factor = 1)
      super()
      @database_document = database_document || nil
      @replication_factor = replication_factor || 1
    end

    def get_command(conventions)
      CreateDatabaseCommand.new(@database_document, @replication_factor)
    end
  end

  class DeleteByIndexOperation < IndexQueryBasedOperation
    def get_command(conventions, store = nil)
      DeleteByIndexCommand.new(@query, @options)
    end 
  end

  class DeleteDatabaseOperation < ServerOperation
    def initialize(database_id, hard_delete = false, from_node = nil)
      super()
      @from_node = from_node
      @database_id = database_id || nil
      @hard_delete = hard_delete
    end

    def get_command(conventions)
      DeleteDatabaseCommand.new(@database_id, @hard_delete, @from_node)
    end
  end

  class DeleteIndexOperation < AdminOperation
    def initialize(index_name)
      super()
      @index_name = index_name || nil
    end
    
    def get_command(conventions)
      DeleteIndexCommand.new(@index_name)
    end
  end

  class GetApiKeyOperation < ServerOperation
    def initialize(name)
      super()
      @name = name || nil
    end
    
    def get_command(conventions)
      GetApiKeyCommand.new(@name)
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
      @index_name = index_name || nil
    end
    
    def get_command(conventions)
      GetIndexCommand.new(@index_name)
    end 
  end

  class GetStatisticsOperation < AdminOperation
    def get_command(conventions)
      GetStatisticsCommand.new
    end
  end

  class PatchByIndexOperation < IndexQueryBasedOperation
    def initialize(query_to_update, patch = nil, options = nil)
      super(query_to_update, options)
      @patch = patch
    end

    def get_command(conventions, store = nil)
      PatchByIndexCommand.new(@query, @patch, @options)
    end 
  end

  class PatchOperation < PatchResultOperation
    @id = nil
    @patch = nil
    @options = nil

    def initialize(id, patch, options = nil)
      super()
      @id = id
      @patch = patch
      @options = options
    end

    def get_command(conventions, store = nil)
      return PatchCommand.new(@id, @patch, @options)
    end
  end

  class PutApiKeyOperation < ServerOperation
    def initialize(name, api_key)
      super()
      @name = name || nil
      @api_key = api_key || nil
    end
    
    def get_command(conventions)
      PutApiKeyCommand.new(@name, @api_key)
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

  class QueryOperationOptions
    attr_reader :allow_stale, :stale_timeout, :max_ops_per_sec, :retrieve_details

    def initialize(allow_stale = true, stale_timeout = nil, max_ops_per_sec = nil, retrieve_details = false)
      @allow_stale = allow_stale
      @stale_timeout = stale_timeout
      @max_ops_per_sec = max_ops_per_sec
      @retrieve_details = retrieve_details
    end
  end
end  