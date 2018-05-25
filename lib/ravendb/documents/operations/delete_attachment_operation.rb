module RavenDB
  class DeleteAttachmentOperation < AttachmentOperation
    def get_command(_conventions, _store = nil)
      DeleteAttachmentCommand.new(@document_id, @name, @change_vector)
    end
  end
end
