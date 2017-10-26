module RavenDB
  class DeleteByQueryCommand < QueryBasedCommand
    def initialize(query, options = nil)
      super(Net::HTTP::Delete::METHOD, query, options)
    end

    def create_request(server_node)
      super(server_node)
      @payload = @query.to_json
    end
  end

  class PatchByQueryCommand < QueryBasedCommand
    def initialize(query_to_update, options = nil)
      super(Net::HTTP::Patch::METHOD, query_to_update, options)
    end

    def create_request(server_node)
      super(server_node)

      @payload = {
        "Query" => @query.to_json,
      }
    end
  end

  class QueryCommand < RavenCommand
    def initialize(conventions, index_query, metadata_only = false, index_entries_only = false)
      super('', Net::HTTP::Post::METHOD)

      if !index_query.is_a?(IndexQuery)
        raise InvalidOperationException, 'Query must be an instance of IndexQuery class'
      end

      if !conventions
        raise InvalidOperationException, 'Document conventions cannot be empty'
      end

      @index_query = index_query
      @conventions = conventions
      @metadata_only = metadata_only
      @index_entries_only = index_entries_only
    end

    def create_request(server_node)
      assert_node(server_node)

      @end_point = "/databases/#{server_node.database}/queries"
      @params = {"query-hash" => @index_query.query_hash}

      if @metadata_only
        add_params('metadata-only', 'true')
      end

      if @index_entries_only
        add_params('debug', 'entries')
      end

      @payload = @index_query.to_json
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPNotFound)
        raise InvalidOperationException, "Error querying index or collection: #{@index_query.query}"
      end

      result
    end
  end
end