module RavenDB
  class DocumentInfo
    attr_accessor :id
    attr_accessor :change_vector
    attr_accessor :ignore_changes
    attr_accessor :metadata
    attr_accessor :document
    attr_accessor :entity
    attr_accessor :new_document
    attr_accessor :collection
    attr_accessor :metadata_instance
    attr_accessor :concurrency_check_mode

    def ignore_changes?
      ignore_changes
    end

    def new_document?
      new_document
    end

    def initialize(document = nil)
      return unless document
      metadata = document["@metadata"]
      if metadata.nil?
        raise "Document must have a metadata"
      end
      id = metadata["@id"]
      if id.nil?
        raise "Document must have an id"
      end
      change_vector = metadata["@change-vector"]
      if change_vector.nil?
        raise("Document #{id} must have a Change Vector")
      end
      self.id = id.to_s
      self.document = document
      self.metadata = metadata
      self.entity = nil
      self.change_vector = change_vector.to_s
    end
  end
end
