module RavenDB
  class GetDocumentCommand < RavenCommand
    def initialize(id_or_ids, includes = nil, metadata_only = false)
      super()

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

      end_point = "/databases/#{server_node.database}/docs?"

      if @includes
        end_point += "&" + URI.encode_www_form("include" => @includes)
      end

      if multi_load
        if @metadata_only
          end_point += "&metadataOnly=True"
        end

        if (ids.map { |id| id.size }).sum > 1024
          @payload = {"Ids" => ids}
          request = Net::HTTP::Post.new(end_point, "Content-Type" => "application/json")
          request.body = payload.to_json
          return request
        end
      end

      end_point += "&" + URI.encode_www_form("id" => (multi_load ? ids : first_id))

      Net::HTTP::Get.new(end_point)
    end

    def read_request?
      true
    end

    def set_response(response)
      RavenDB.logger.warn("GetDocuments -> #{response}")
      RavenDB.logger.warn("GetDocuments -> #{response.body}")
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
