require 'database/exceptions'
require 'documents/document_query'
require "documents/indexes"
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

  class QueryBasedOperation < AwaitableOperation
    def initialize(query, options = nil)
      super()
      @query = query || nil
      @options = options || QueryOperationOptions.new
    end
  end
end

require_relative './operations/databases'
require_relative './operations/indexes'
require_relative './operations/queries'