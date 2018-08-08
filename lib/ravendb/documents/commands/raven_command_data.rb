module RavenDB
  class RavenCommandData
    attr_reader :id
    attr_reader :type
    attr_reader :name

    def initialize(id, change_vector)
      @id = id
      @change_vector = change_vector
      @type = nil
    end

    def document_id
      @id
    end

    def to_json
      {
        "Type" => @type,
        "Id" => @id,
        "ChangeVector" => @change_vector
      }
    end
  end
end
