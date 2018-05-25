module RavenDB
  class PutAttachmentOperation < Operation
    def initialize(document_id:, name:, stream:, content_type: nil, change_vector: nil)
      super()
      @document_id = document_id
      @name = name
      @change_vector = change_vector
      @stream = stream
      @content_type = content_type
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      PutAttachmentCommand.new(@document_id, @name, @stream, @content_type, @change_vector)
    end
  end
end
