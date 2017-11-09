require 'stringio'

module RavenDB
  class StringBuilder
    def initialize
      @io = StringIO.new
    end

    def append(string)
      @io.print(string)
    end

    def to_string
      @io.string
    end
  end
end