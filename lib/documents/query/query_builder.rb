require 'utilities/linked_list'
require 'database/exceptions'
require 'utilities/observable'
require 'constants/documents'

module RavenDB
  class QueryBuilder
    include Observable

    def initialize(index_name = nil, collection_name = nil, id_property_name = nil)
      unless index_name.nil? && collection_name.nil?
        from(index_name, collection_name)
      end

      @group_by_tokens = LinkedList.new
      @order_by_tokens = LinkedList.new
      @select_tokens = LinkedList.new
      @where_tokens = LinkedList.new
      @alias_to_group_by_field_name = {}
      @includes = Set.new([])
      @id_property_name = id_property_name
      @query_raw = nil
    end

    def raw_query(query)
      unless [@group_by_tokens, @order_by_tokens,
        @select_tokens, @where_tokens].all? {|tokens| tokens.empty?}
        raise InvalidOperationException,
          "You can only use RawQuery on a new query, "\
          "without applying any operations (such as Where, Select, OrderBy, GroupBy, etc)"
      end

      @query_raw = query
      self
    end

    def from(index_name = nil, collection_name = nil)
      self
    end

    def to_string
      unless @query_raw.nil?
        return @query_raw
      end

      #TODO: build query from tokens
    end
  end
end