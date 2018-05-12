module RavenDB
  class PatchCommandData < RavenCommandData
    def initialize(id, scripted_patch, change_vector = nil, patch_if_missing = nil, debug_mode = nil)
      super(id, change_vector)

      @type = Net::HTTP::Patch::METHOD
      @scripted_patch = scripted_patch
      @patch_if_missing = patch_if_missing
      @debug_mode = debug_mode
      @additional_data = nil
    end

    def to_json
      json = super().merge(
        "Patch" => @scripted_patch.to_json,
        "DebugMode" => @debug_mode
      )

      unless @patch_if_missing.nil?
        json["PatchIfMissing"] = @patch_if_missing.to_json
      end

      json
    end
  end
end
