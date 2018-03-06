module RavenDB
  class LinkedListItem
    attr_accessor :value

    def index
      @list_items.index(self)
    end

    def first
      index <= 0
    end

    def last
      (index < 0) || (index >= (@list_items.size - 1))
    end

    def previous
      if first
        return nil
      end

      @list_items[index - 1]
    end

    def next
      if last
        return nil
      end

      @list_items[index + 1]
    end

    def initialize(value, list_items)
      @value = value
      @list_items = list_items
    end
  end

  class LinkedList
    def count
      @items.size
    end

    def empty?
      @items.empty?
    end

    def first
      return nil if empty?

      @items.first
    end

    def last
      return nil if empty?

      @items.last
    end

    def initialize(items = [])
      @items = []

      if items.size
        items.each { |item| add_last(item) }
      end
    end

    def add_last(item)
      @items.push(LinkedListItem.new(item, @items))
      self
    end

    def add_first(item)
      @items.unshift(LinkedListItem.new(item, @items))
      self
    end

    def clear
      @items = []

      self
    end

    def each
      return unless block_given?

      @items.each { |linked_list_item| yield(linked_list_item) }
    end
  end
end
