module RavenDB
  class IdTypeAndName
    attr_accessor :id
    attr_accessor :type
    attr_accessor :name

    def ==(other)
      id == other.id &&
        type == other.type &&
        name == other.name
    end

    alias eql? ==

    def hash
      id.hash ^ type.hash ^ name.hash
    end

    def initialize(id, type, name)
      self.id = id
      self.type = type
      self.name = name
    end
  end
end
