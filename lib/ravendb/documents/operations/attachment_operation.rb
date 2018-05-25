module RavenDB
  class AttachmentOperation < Operation
    def initialize(document_id, name, change_vector = nil)
      super()
      @document_id = document_id
      @name = name
      @change_vector = change_vector
    end
  end
end
