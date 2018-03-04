module RavenDB
  class DeleteIndexCommand < RavenCommand
    def initialize(index_name)
      super("", Net::HTTP::Delete::METHOD)
      @index_name = index_name || nil
    end

    def create_request(server_node)
      assert_node(server_node)

      unless @index_name
        raise "nil or empty index_name is invalid"
      end

      @params = {"name" => @index_name}
      @end_point = "/databases/#{server_node.database}/indexes"
    end
  end

  class GetIndexesCommand < RavenCommand
    def initialize(start = 0, page_size = 10)
      super("", Net::HTTP::Get::METHOD, nil, nil, {})
      @start = start
      @page_size = page_size
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "/databases/#{server_node.database}/indexes"
      @params = { "start" => @start, "page_size" => @page_size }
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPNotFound)
        raise IndexDoesNotExistException, "Can't find requested index(es)"
      end

      unless response.body
        return
      end

      result["Results"]
    end
  end

  class GetIndexCommand < GetIndexesCommand
    def initialize(index_name)
      super()
      @index_name = index_name || nil
    end

    def create_request(server_node)
      super(server_node)
      @params = {"name" => @index_name}
    end

    def set_response(response)
      results = super(response)

      if results.is_a?(Array)
        results.first
      end
    end
  end

  class PutIndexesCommand < RavenCommand
    def initialize(indexes_to_add, *more_indexes_to_add)
      @indexes = []
      indexes = indexes_to_add.is_a?(Array) ? indexes_to_add : [indexes_to_add]

      if more_indexes_to_add.is_a?(Array) && !more_indexes_to_add.empty?
        indexes = indexes.concat(more_indexes_to_add)
      end

      super("", Net::HTTP::Put::METHOD)

      if indexes.empty?
        raise "No indexes specified"
      end

      indexes.each do |index|
        unless index.is_a?(IndexDefinition)
          raise "All indexes should be instances of IndexDefinition"
        end

        unless index.name
          raise "All indexes should have a name"
        end

        @indexes.push(index)
      end
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "/databases/#{server_node.database}/admin/indexes"
      @payload = {"Indexes" => @indexes.map { |index| index.to_json }}
    end

    def set_response(response)
      result = super(response)

      unless response.body
        throw raise ErrorResponseException, "Failed to put indexes to the database "\
  "please check the connection to the server"
      end

      result
    end
  end
end