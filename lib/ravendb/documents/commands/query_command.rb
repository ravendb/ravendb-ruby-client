module RavenDB
  class QueryCommand < RavenCommand
    def initialize(conventions, index_query, metadata_only = false, index_entries_only = false)
      super()

      unless index_query.is_a?(IndexQuery)
        raise "Query must be an instance of IndexQuery class"
      end

      unless conventions
        raise "Document conventions cannot be empty"
      end

      @index_query = index_query
      @conventions = conventions
      @metadata_only = metadata_only
      @index_entries_only = index_entries_only
    end

    def create_request(server_node)
      assert_node(server_node)

      end_point = "/databases/#{server_node.database}/queries?queryHash=" + @index_query.query_hash

      if @metadata_only
        end_point += "&metadataOnly=true"
      end

      if @index_entries_only
        end_point += "&debug=entries"
      end

      payload = @index_query.to_json

      request = Net::HTTP::Post.new(end_point, "Content-Type" => "application/json")
      request.body = payload.to_json
      request
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPNotFound)
        raise IndexDoesNotExistException, "Error querying index or collection: #{@index_query.query}"
      end

      result
    end

    def read_request?
      true
    end
  end
end
