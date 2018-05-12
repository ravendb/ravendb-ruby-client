module RavenDB
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
