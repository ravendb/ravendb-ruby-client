module RavenDB
  class DeleteCommandData < RavenCommandData
    def initialize(id, change_vector = nil)
      super(id, change_vector)
      @type = Net::HTTP::Delete::METHOD
    end

    def serialize(_conventions)
      {
        "Id" => @id,
        "ChangeVector" => @change_vector,
        "Type" => @type
      }
    end
  end
end
