require 'database/exceptions'

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