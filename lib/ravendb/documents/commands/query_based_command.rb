module RavenDB
  class QueryBasedCommand < RavenCommand
    def initialize(query, options = nil)
      super()
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

      params = {
        "allowStale" => options.allow_stale,
        "details" => options.retrieve_details,
        "maxOpsPerSec" => options.max_ops_per_sec
      }

      end_point = "/databases/#{server_node.database}/queries?" + params.map { |k, v| "#{k}=#{v}" }.join("&")

      if options.allow_stale && options.stale_timeout
        end_point += "&staleTimeout=#{options.stale_timeout}"
      end

      request = http_method.new(end_point, "Content-Type" => "application/json")
      request.body = payload.to_json
      request
    end
  end
end
