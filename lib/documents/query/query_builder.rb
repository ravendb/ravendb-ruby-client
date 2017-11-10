require 'utilities/linked_list'
require 'database/exceptions'
require 'utilities/observable'
require 'utilities/string_utility'
require 'constants/documents'
require 'documents/query/query_tokens'

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
      @fields_to_fetch_token = nil
      @id_property_name = id_property_name
      @query_raw = nil
      @default_operator = nil
      @is_group_by = false
      @is_intersect = false
      @is_distinct = false
      @negate = false
      @current_clause_depth = 0
    end

    def is_dynamic_map_reduce
      !@group_by_tokens.empty?
    end

    def select_fields(fields, projections = nil)
      if !projections.is_a?(Array) || projections.empty?
        projections = fields
      end

      update_fields_to_fetch_token(FieldsToFetchToken.create(fields, projections))
      self
    end

    def using_default_operator(operator)
      raise InvalidOperationException,
        "Default operator can only be set "\
        "before any where clause is added." unless
        @where_tokens.empty?

      @default_operator = operator
      self
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
      @from_token = FromToken.create(index_name, collection_name)

      self
    end

    def get_projections_fields
      unless @fields_to_fetch_token.nil?
        return @fields_to_fetch_token.projections || []
      end

      []
    end

    def add_group_by_alias(field_name, projected_name)
      @alias_to_group_by_field_name[projected_name] = field_name
    end

    def random_ordering(seed = nil)
      assert_no_raw_query

      @order_by_tokens.add_last(seed ?
        OrderByToken.create_random(seed) :
        OrderByToken.random
      )

      self
    end

    def custom_sort_using(type_name, descending = false)
      field_name = "#{FieldConstants::CustomSortFieldName};#{type_name}"

      descending ?
        order_by_descending(field_name) :
        order_by(field_name)
    end

    def include(path)
      @includes.add(path)

      self
    end

    def where_equals(field_or_params, parameter_name = nil, exact = false)
      field_name = field_or_params
      params = field_or_params

      unless field_or_params.is_a?(Hash)
        return where_equals({
          :parameter_name => parameter_name,
          :field_name => field_name,
          :exact => exact
        })
      end

      if @negate
        @negate = false
        return where_not_equals(params)
      end

      params[:field_name] = ensure_valid_field_name(params[:field_name], params[:is_nested_path])

      append_operator_if_needed(@where_tokens)
      @where_tokens.add_last(WhereToken.equals(params[:field_name], params[:parameter_name], params[:exact]))

      self
    end

    def where_not_equals(field_or_params, parameter_name = nil, exact = false)
      field_name = field_or_params
      params = field_or_params

      unless field_or_params.is_a?(Hash)
        return where_not_equals({
          :parameter_name => parameter_name,
          :field_name => field_name,
          :exact => exact
        })
      end

      if @negate
        @negate = false
        return where_equals(params)
      end

      params[:field_name] = ensure_valid_field_name(params[:field_name], params[:is_nested_path])

      append_operator_if_needed(@where_tokens)
      @where_tokens.add_last(WhereToken.not_equals(params[:field_name], params[:parameter_name], params[:exact]))

      self
    end

    def open_subclause
      @current_clause_depth = @current_clause_depth + 1
      append_operator_if_needed(@where_tokens)
      negate_if_needed
      @where_tokens.add_last(OpenSubclauseToken.instance)

      self
    end

    def close_subclause
      @current_clause_depth = @current_clause_depth - 1
      @where_tokens.add_last(CloseSubclauseToken.instance)

      self
    end

    def negate_next
      @negate = !@negate

      self
    end

    def where_exists(field_name)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.exists(field_name))

      self
    end

    def and_also
      if @where_tokens.last.nil?
          return self
      end

      if @where_tokens.last.value.is_a?(QueryOperatorToken)
        raise InvalidOperationException, "Cannot add AND, previous token was already an operator token."
      end

      @where_tokens.add_last(QueryOperatorToken.And)

      self
    end

    def order_by(field, ordering_type = nil)
      assert_no_raw_query

      field = ensure_valid_field_name(field)
      @order_by_tokens.add_last(OrderByToken.create_ascending(field, ordering_type))

      self
    end

    def order_by_descending(field, ordering_type = nil)
      assert_no_raw_query

      field = ensure_valid_field_name(field)
      @order_by_tokens.add_last(OrderByToken.create_descending(field, ordering_type))

      self
    end

    def to_string
      unless @query_raw.nil?
        return @query_raw
      end

      #TODO: build query from tokens
    end

    protected
    def ensure_valid_field_name(field_name, is_nested_path = false)
      result = {
        :original_field_name => field_name,
        :escaped_field_name => StringUtilities::escape_if_necessary(field_name)
      }

      if @is_group_by && !is_nested_path
          if !@id_property_name.nil? && (field_name == @id_property_name)
            result[:escaped_field_name] = FieldConstants::DocumentIdFieldName
          end

        emit(RavenServerEvent::EVENT_QUERY_FIELD_VALIDATED, result)
      end

      result[:escaped_field_name]
    end

    def append_operator_if_needed(tokens)
      assert_no_raw_query

      if tokens.empty?
          return
      end

      last_token = tokens.last.value

      unless [WhereToken, CloseSubclauseToken].any? {|token_type| last_token.is_a?(token_type)}
        return
      end

      current = tokens.last
      last_where = nil

      until current.nil?
        if current.value.is_a?(WhereToken)
          last_where = current.value
          break
        end

        current = current.previous
      end

      token = (QueryOperator::And == @default_operator) ?
        QueryOperatorToken.and : QueryOperatorToken.or

      unless last_where.nil? || last_where.search_operator.nil?
        token = QueryOperatorToken.Or
      end

      tokens.add_last(token)
    end

    def negate_if_needed(field_name = nil)
      unless @negate
        return
      end

      @negate = false

      if @where_tokens.empty? || @where_tokens.last.value.is_a?(OpenSubclauseToken)
        field_name.nil ? where_true : where_exists(field_name)

        and_also
      end

      @where_tokens.add_last(NegateToken.instance)
    end

    def update_fields_to_fetch_token(fields_to_fetch)
      tokens = @select_tokens
      found_token = find_fields_to_fetch_token

      @fields_to_fetch_token = fields_to_fetch

      if found_token
        found_token.value = fields_to_fetch
      else
        tokens.add_last(fields_to_fetch)
      end
    end

    def find_fields_to_fetch_token
      tokens = @select_tokens
      result = nil
      found = false

      tokens.each do |item|
        if !found && (item.value.is_a?(FieldsToFetchToken))
          found = true
          result = item
        end
      end

      result
    end

    def assert_no_raw_query
      raise InvalidOperationException,
        "RawQuery was called, cannot modify this query by calling on operations that "\
        "would modify the query (such as Where, Select, OrderBy, GroupBy, etc)" unless
        @query_raw.nil?
    end
  end
end