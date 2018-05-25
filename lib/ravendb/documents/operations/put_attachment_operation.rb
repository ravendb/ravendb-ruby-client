module RavenDB
  class PutAttachmentOperation < AttachmentOperation
    def initialize(document_id, name, stream, content_type = nil, change_vector = nil)
      super(document_id, name, change_vector)

      @stream = stream
      @content_type = content_type
    end

    def get_command(_conventions, _store = nil)
      PutAttachmentCommand.new(@document_id, @name, @stream, @content_type, @change_vector)
    end
  end
end
