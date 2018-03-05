module RavenDB
  class DeleteDocumentCommand < RavenCommand
    def initialize(id, change_vector = nil)
      super("", Net::HTTP::Delete::METHOD)

      @id = id || nil
      @change_vector = change_vector
    end

    def create_request(server_node)
      assert_node(server_node)

      unless @id
        raise "Nil Id is not valid"
      end

      unless @id.is_a?(String)
        raise "Id must be a string"
      end

      if @change_vector
        @headers = {"If-Match" => "\"#{@change_vector}\""}
      end

      @params = {"id" => @id}
      @end_point = "/databases/#{server_node.database}/docs"
    end

    def set_response(response)
      super(response)
      check_response(response)
    end

    protected

    def check_response(response)
      unless response.is_a?(Net::HTTPNoContent)
        raise "Could not delete document #{@id}"
      end
    end
  end

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

  class PatchCommand < RavenCommand
    def initialize(id, patch, options = nil)
      super("", Net::HTTP::Patch::METHOD)
      opts = options || {}

      @id = id || nil
      @patch = patch || nil
      @change_vector = opts[:change_vector] || nil
      @patch_if_missing = opts[:patch_if_missing] || nil
      @skip_patch_if_change_vector_mismatch = opts[:skip_patch_if_change_vector_mismatch] || false
      @return_debug_information = opts[:return_debug_information] || false
    end

    def create_request(server_node)
      assert_node(server_node)

      if @id.nil?
        raise "Empty ID is invalid"
      end

      if @patch.nil?
        raise "Empty patch is invalid"
      end

      if @patch_if_missing && !@patch_if_missing.script
        raise "Empty script is invalid"
      end

      @params = {"id" => @id}
      @end_point = "/databases/#{server_node.database}/docs"

      if @skip_patch_if_change_vector_mismatch
        add_params("skipPatchIfChangeVectorMismatch", "true")
      end

      if @return_debug_information
        add_params("debug", "true")
      end

      unless @change_vector.nil?
        @headers = {"If-Match" => "\"#{@change_vector}\""}
      end

      @payload = {
        "Patch" => @patch.to_json,
        "PatchIfMissing" => @patch_if_missing ? @patch_if_missing.to_json : nil
      }
    end

    def set_response(response)
      result = super(response)

      if !response.is_a?(Net::HTTPOK) && !response.is_a?(Net::HTTPNotModified)
        raise "Could not patch document #{@id}"
      end

      if response.body
        result
      end
    end
  end

  class PutDocumentCommand < DeleteDocumentCommand
    def initialize(id, document, change_vector = nil)
      super(id, change_vector)

      @document = document || nil
      @method = Net::HTTP::Put::METHOD
    end

    def create_request(server_node)
      unless @document
        raise "Document must be an object"
      end

      @payload = @document
      super(server_node)
    end

    def set_response(response)
      super(response)
      response.body
    end

    protected

    def check_response(response)
      unless response.body
        raise ErrorResponseException, "Failed to store document to the database "\
  "please check the connection to the server"
      end
    end
  end
end
