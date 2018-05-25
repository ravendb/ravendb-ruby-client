module RavenDB
  class QueryBasedOperation < AwaitableOperation
    def initialize(query, options = nil)
      super()
      @query = query
      @options = options || QueryOperationOptions.new
    end
  end
end
