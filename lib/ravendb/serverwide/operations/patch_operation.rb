module RavenDB
  class PatchOperation < PatchResultOperation
    attr_reader :id

    def initialize(id, patch, options = nil)
      super()
      @id = id
      @patch = patch
      @options = options
    end

    def get_command(_conventions, _store = nil)
      PatchCommand.new(@id, @patch, @options)
    end
  end
end
