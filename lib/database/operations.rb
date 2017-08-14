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
    @index_name = nil
    @query = nil
    @options = nil

    def initialize(index_name, query, options = nil)
      super()
      @index_name = index_name
      @query = query
      @options = options || QueryOperationOptions.new
    end
  end

  class CreateDatabaseOperation < ServerOperation
    @replication_factor = nil
    @database_document = nil

    def initialize(database_document, replication_factor = 1)
      super()
      @database_document = database_document
      @replication_factor = replication_factor || 1
    end

    def get_command(conventions)
      return CreateDatabaseCommand.new(@database_document, @replication_factor)
    end
  end

  class DeleteByIndexOperation < IndexQueryBasedOperation
    def get_command(conventions, store = nil)
      return DeleteByIndexCommand.new(@index_name, @query, @options)
    end 
  end

  class DeleteDatabaseOperation < ServerOperation
    @database_id = nil
    @hard_delete = false
    @from_node = nil

    def initialize(database_id, hard_delete = false, from_node = nil)
      super()
      @from_node = from_node
      @database_id = database_id
      @hard_delete = hard_delete
    end

    def get_command(conventions)
      return  DeleteDatabaseCommand.new(database_id, hard_delete, from_node)
    end
  end

  class DeleteIndexOperation < AdminOperation
    @index_name = nil

    def initialize(index_name)
      super()
      @index_name = index_name
    end
    
    def get_command(conventions)
      return DeleteIndexCommand.new(@index_name)
    end
  end

  class GetApiKeyOperation < ServerOperation
    @name = nil

    def initialize(name)
      super()
      @name = name
    end
    
    def get_command(conventions)
      return GetApiKeyCommand.new(@name)
    end
  end

  class GetIndexesOperation < AdminOperation
    @start = nil
    @page_size = nil

    def initialize(start = 0, page_size = 10)
      super()
      @start = start
      @page_size = page_size
    end
    
    def get_command(conventions)
      return GetIndexesCommand.new(@start, @page_size)
    end 
  end

  class GetIndexOperation < AdminOperation
    @index_name = nil

    def initialize(index_name)
      super()
      @index_name = index_name
    end
    
    def get_command(conventions)
      return GetIndexCommand.new(@index_name)
    end 
  end

  class GetStatisticsOperation < AdminOperation
    def get_command(conventions)
      return GetStatisticsCommand.new
    end
  end

  class PatchByIndexOperation < IndexQueryBasedOperation
    @patch = nil

    def initialize(index_name, query_to_update, patch = nil, options = nil)
      super(index_name, query_to_update, options)
      @patch = patch
    end

    def get_command(conventions, store = nil)
      return PatchByIndexCommand.new(@index_name, @query, @patch, @options)
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
    @name = nil
    @api_key = nil

    def initialize(name, api_key)
      super()
      @name = name
      @api_key = api_key
    end
    
    def get_command(conventions)
      return PutApiKeyCommand.new(@name, api_key)
    end
  end

  class PutIndexesOperation < AdminOperation
    @indexes = []

    def initialize(indexes_to_add, *more_indexes_to_add)
      indexes = indexes_to_add.is_a?(Array) ? indexes_to_add : [indexes_to_add]

      if more_indexes_to_add.is_a?(Array) && !more_indexes_to_add.empty?
        indexes = indexes.concat(more_indexes_to_add)
      end

      super()
      @indexes = indexes
    end
    
    def get_command(conventions)
      return PutIndexesCommand.new(@indexes)
    end
  end

  

  class QueryOperationOptions
    @_allow_stale = true
    @_stale_timeout = nil
    @_max_ops_per_sec = nil
    @_retrieve_details = false

    def initialize(allow_stale = true, stale_timeout = nil, max_ops_per_sec = nil, retrieve_details = false)
      @allow_stale = allow_stale
      @stale_timeout = stale_timeout
      @max_ops_per_sec = max_ops_per_sec
      @retrieve_details = retrieve_details
    end

    def get allow_stale
      @_allow_stale
    end

    def get stale_timeout
      @_stale_timeout
    end

    def get max_ops_per_sec
      @_max_ops_per_sec
    end

    def get retrieve_details
      @_retrieve_details
    end
  end
end  