module RavenDB
  class PutAttachmentCommandData
    def initialize(document_id, name, stream, content_type, change_vector)
      raise ArgumentError, "DocumentId cannot be null" if document_id.nil?
      raise ArgumentError, "Name cannot be null" if name.nil?

      self.id = document_id
      self.name = name
      self.stream = stream
      self.content_type = content_type
      self.change_vector = change_vector
    end

    attr_reader :id
    attr_reader :name
    attr_reader :stream
    attr_reader :change_vector
    attr_reader :content_type
    attr_reader :type

    def serialize(_conventions)
      {
        "Id" => @id,
        "Name" => @name,
        "ContentType" => @content_type,
        "ChangeVector" => @change_vector,
        "Type" => "AttachmentPUT"
      }
    end
  end
end
