module RavenDB
  class AttachmentOperation < Operation
    def initialize(document_id, name, change_vector = nil)
      super()
      @document_id = document_id
      @name = name
      @change_vector = change_vector
    end
  end

  class DeleteAttachmentOperation < AttachmentOperation
    def get_command(conventions, store = nil)
      DeleteAttachmentCommand.new(@document_id, @name, @change_vector)
    end
  end

  class GetAttachmentOperation < AttachmentOperation
    def initialize(document_id, name, type, change_vector = nil)
      super(document_id, name, change_vector)

      @type = type
    end

    def get_command(conventions, store = nil)
      GetAttachmentCommand.new(@document_id, @name, @type, @change_vector)
    end
  end

  class PutAttachmentOperation < AttachmentOperation
    def initialize(document_id, name, stream, content_type = nil, change_vector = nil)
      super(document_id, name, change_vector)

      @stream = stream
      @content_type = content_type
    end

    def get_command(conventions, store = nil)
      PutAttachmentCommand.new(@document_id, @name, @stream, @content_type, @change_vector)
    end
  end
end
