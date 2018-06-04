module RavenDB
  class PatchCommand < RavenCommand
    def initialize(id:, patch:, change_vector: nil, patch_if_missing: nil, skip_patch_if_change_vector_mismatch: false, return_debug_information: false, test: false)
      super()

      @id = id
      @patch = patch
      @change_vector = change_vector
      @patch_if_missing = patch_if_missing
      @skip_patch_if_change_vector_mismatch = skip_patch_if_change_vector_mismatch
      @return_debug_information = return_debug_information
      @test = test
    end

    def read_request?
      false
    end

    def create_request(server_node)
      assert_node(server_node)

      raise "Id cannot be null" unless @id
      raise "Patch cannot be null" unless @patch
      raise "Patch.Script cannot be null" unless @patch.script
      raise "PatchIfMissing.Script cannot be null" if @patch_if_missing && !@patch_if_missing.script

      end_point = "/databases/#{server_node.database}/docs"

      params = {}

      params["id"] = @id
      params["skipPatchIfChangeVectorMismatch"] = true if @skip_patch_if_change_vector_mismatch
      params["debug"] = true if @return_debug_information
      params["test"] = true if @test

      request = Net::HTTP::Patch.new(path_with_params(end_point, params), "Content-Type" => "application/json")

      add_change_vector_if_not_null(@change_vector, request)

      payload = {
        "Patch" => @patch.to_json,
        "PatchIfMissing" => @patch_if_missing&.to_json
      }

      request.body = payload.to_json
      request
    end

    def add_change_vector_if_not_null(change_vector, request)
      request["If-Match"] = "\"#{change_vector}\"" unless change_vector.nil?
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
