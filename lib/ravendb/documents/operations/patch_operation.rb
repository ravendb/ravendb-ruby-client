module RavenDB
  class PatchOperation < Operation
    attr_reader :id

    def initialize(id, patch, options = nil)
      super()
      @id = id
      @patch = patch
      @options = options
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      PatchCommand.new(@id, @patch, @options)
    end
  end
end
