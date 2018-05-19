module RavenDB
  class PatchCommand < RavenCommand
    def initialize(id, patch, options = nil)
      super()
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

      raise "Empty ID is invalid" if @id.nil?
      raise "Empty patch is invalid" if @patch.nil?
      raise "Empty script is invalid" if @patch_if_missing && !@patch_if_missing.script

      end_point = "/databases/#{server_node.database}/docs?id=#{@id}"

      if @skip_patch_if_change_vector_mismatch
        end_point += "&skipPatchIfChangeVectorMismatch=true"
      end

      if @return_debug_information
        end_point += "&debug=true"
      end

      request = Net::HTTP::Patch.new(end_point, "Content-Type" => "application/json")

      unless @change_vector.nil?
        request["If-Match"] = "\"#{@change_vector}\""
      end

      payload = {
        "Patch" => @patch.to_json,
        "PatchIfMissing" => @patch_if_missing ? @patch_if_missing.to_json : nil
      }

      request.body = payload.to_json
      request
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
