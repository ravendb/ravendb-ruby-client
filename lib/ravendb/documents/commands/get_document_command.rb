module RavenDB
  class GetDocumentCommand < RavenCommand
    def initialize(id_or_ids, includes = nil, metadata_only = false)
      super("", Net::HTTP::Get::METHOD, nil, nil, {})

      @id_or_ids = id_or_ids || []
      @includes = includes
      @metadata_only = metadata_only
    end

    def create_request(server_node)
      assert_node(server_node)

      unless @id_or_ids
        raise "nil ID is not valid"
      end

      ids = @id_or_ids.is_a?(Array) ? @id_or_ids : [@id_or_ids]
      first_id = ids.first
      multi_load = ids.size > 1

      @params = {}
      @end_point = "/databases/#{server_node.database}/docs"

      if @includes
        add_params("include", @includes)
      end

      if multi_load
        if @metadata_only
          add_params("metadataOnly", "True")
        end

        if (ids.map { |id| id.size }).sum > 1024
          @payload = {"Ids" => ids}
          @method = Net::HTTP::Post::METHOD

          return
        end
      end

      add_params("id", multi_load ? ids : first_id)
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPNotFound)
        return
      end

      unless response.body
        raise ErrorResponseException, "Failed to load document from the database "\
  "please check the connection to the server"
      end

      result
    end
  end
end
