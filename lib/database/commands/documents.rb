require "database/commands/put_document_command"
require "database/commands/delete_document_command"

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

  class PatchCommand < RavenCommand
    def initialize(id, patch, options = nil)
      super("", Net::HTTP::Patch::METHOD)
      opts = options || {}

      @id = id
      @patch = patch
      @change_vector = opts[:change_vector]
      @patch_if_missing = opts[:patch_if_missing]
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

      result if response.body
    end
  end
end
