module RavenDB
  class PatchOperation < Operation
    attr_reader :id

    def initialize(id:, patch:, change_vector: nil, patch_if_missing: nil, skip_patch_if_change_vector_mismatch: false, return_debug_information: false)
      super()
      @id = id
      @patch = patch
      @change_vector = change_vector
      @patch_if_missing = patch_if_missing
      @skip_patch_if_change_vector_mismatch = skip_patch_if_change_vector_mismatch
      @return_debug_information = return_debug_information
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      PatchCommand.new(id: @id,
                       patch: @patch,
                       change_vector: @change_vector,
                       patch_if_missing: @patch_if_missing,
                       skip_patch_if_change_vector_mismatch: @skip_patch_if_change_vector_mismatch,
                       return_debug_information: @return_debug_information
                      )
    end
  end
end
