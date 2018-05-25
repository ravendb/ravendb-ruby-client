module RavenDB
  class DeleteAttachmentOperation < AttachmentOperation
    def get_command(conventions:, store: nil, http_cache: nil)
      DeleteAttachmentCommand.new(@document_id, @name, @change_vector)
    end
  end
end
