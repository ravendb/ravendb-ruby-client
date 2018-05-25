module RavenDB
  class GetAttachmentOperation < Operation
    def initialize(document_id:, name:, type:, change_vector: nil)
      super()
      @document_id = document_id
      @name = name
      @change_vector = change_vector
      @type = type
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      GetAttachmentCommand.new(@document_id, @name, @type, @change_vector)
    end
  end
end
