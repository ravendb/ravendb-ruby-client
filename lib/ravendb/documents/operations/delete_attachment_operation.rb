module RavenDB
  class DeleteAttachmentOperation < Operation
    def initialize(document_id:, name:, change_vector: nil)
      super()
      @document_id = document_id
      @name = name
      @change_vector = change_vector
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      DeleteAttachmentCommand.new(@document_id, @name, @change_vector)
    end
  end
end
