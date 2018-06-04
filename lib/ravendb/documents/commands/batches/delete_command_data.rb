module RavenDB
  class DeleteCommandData < RavenCommandData
    def initialize(id, change_vector = nil)
      super(id, change_vector)
      @type = Net::HTTP::Delete::METHOD
    end
  end
end
