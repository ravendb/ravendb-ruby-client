module RavenDB
  class QueryBasedCommand < RavenCommand
    def initialize(method, query, options = nil)
      super("", method)
      @query = query
      @options = options || QueryOperationOptions.new
    end

    def create_request(server_node)
      assert_node(server_node)
      query = @query
      options = @options

      unless query.is_a?(IndexQuery)
        raise "Query must be instance of IndexQuery class"
      end

      unless options.is_a?(QueryOperationOptions)
        raise "Options must be instance of QueryOperationOptions class"
      end

      @params = {
          "allowStale" => options.allow_stale,
          "details" => options.retrieve_details,
          "maxOpsPerSec" => options.max_ops_per_sec
      }

      @end_point = "/databases/#{server_node.database}/queries"

      return unless options.allow_stale && options.stale_timeout

      add_params("staleTimeout", options.stale_timeout)
    end
  end
end
