module RavenDB
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
