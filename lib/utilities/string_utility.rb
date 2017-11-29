require 'stringio'

class String
  def alnum?
    !!match(/^[[:alnum:]]+$/)
  end

  def alpha?
    !!match(/^[[:alpha:]]+$/)
  end

  def number?
    !!match(/^\d+$/)
  end
end

module RavenDB
  class StringBuilder
    def initialize
      @io = StringIO.new
    end

    def append(string)
      @io.print(string)

      self
    end

    def to_string
      @io.string
    end
  end

  class StringUtilities
    def self.escape_if_necessary(string)
      if string.nil? || string.empty?
          return string
      end

      escape = false

      string.chars.each_with_index do |c, i|
        if i == 0
          if !c.alpha? && !['_', '@'].include?(c)
            escape = true
            break
          end

          next
        end

        if !c.alnum? && !['_', '@', '.', '[', ']'].include?(c)
          escape = true
          break
        end
      end

      if escape
        return "'#{string}'"
      end

      string
    end
  end
end