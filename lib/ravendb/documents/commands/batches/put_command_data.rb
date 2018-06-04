module RavenDB
  class PutCommandData < RavenCommandData
    def initialize(id, document, change_vector = nil, metadata = nil)
      super(id, change_vector)

      @type = Net::HTTP::Put::METHOD
      @document = document
      @metadata = metadata
    end

    def to_json
      json = super()
      document = @document

      if @metadata
        document["@metadata"] = @metadata
      end

      json["Document"] = document
      json
    end
  end
end
