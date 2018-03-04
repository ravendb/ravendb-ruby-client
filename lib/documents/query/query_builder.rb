require "utilities/linked_list"
require "database/exceptions"
require "utilities/observable"
require "utilities/string_utility"
require "constants/documents"
require "documents/query/query_tokens"
require "documents/query/spatial"

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
      unless @where_tokens.empty?
        raise "Default operator can only be set "\
              "before any where clause is added."
      end

      @default_operator = operator
      self
    end

    def raw_query(query)
      unless [@group_by_tokens, @order_by_tokens,
        @select_tokens, @where_tokens].all? {|tokens| tokens.empty?}
        raise "You can only use RawQuery on a new query, "\
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
        return where_equals(
          parameter_name: parameter_name,
          field_name: field_name,
          exact: exact
        )
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
        return where_not_equals(
          parameter_name: parameter_name,
          field_name: field_name,
          exact: exact
        )
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
      @current_clause_depth += 1
      append_operator_if_needed(@where_tokens)
      negate_if_needed
      @where_tokens.add_last(OpenSubclauseToken.instance)

      self
    end

    def close_subclause
      @current_clause_depth -= 1
      @where_tokens.add_last(CloseSubclauseToken.instance)

      self
    end

    def negate_next
      @negate = !@negate

      self
    end

    def where_in(field_name, parameter_name, exact = false)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.in(field_name, parameter_name, exact))

      self
    end

    def where_all_in(field_name, parameter_name)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.all_in(field_name, parameter_name))

      self
    end

    def where_starts_with(field_name, parameter_name)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.starts_with(field_name, parameter_name))

      self
    end

    def where_ends_with(field_name, parameter_name)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.ends_with(field_name, parameter_name))

      self
    end

    def where_between(field_name, from_parameter_name, to_parameter_name, exact = false)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.between(field_name, from_parameter_name, to_parameter_name, exact))

      self
    end

    def where_greater_than(field_name, parameter_name, exact = false)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.greater_than(field_name, parameter_name, exact))

      self
    end

    def where_greater_than_or_equal(field_name, parameter_name, exact = false)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.greater_than_or_equal(field_name, parameter_name, exact))

      self
    end

    def where_less_than_or_equal(field_name, parameter_name, exact = false)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.less_than_or_equal(field_name, parameter_name, exact))

      self
    end

    def where_less_than(field_name, parameter_name, exact = false)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.less_than(field_name, parameter_name, exact))

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
        raise "Cannot add AND, previous token was already an operator token."
      end

      @where_tokens.add_last(QueryOperatorToken.and)

      self
    end

    def or_else
      if @where_tokens.last.nil?
        return self
      end

      if @where_tokens.last.value.is_a?(QueryOperatorToken)
        raise "Cannot add OR, previous token was already an operator token."
      end

      @where_tokens.add_last(QueryOperatorToken.or)

      self
    end

    def boost(boost)
      if 1 == boost
        return self
      end

      if boost <= 0
        raise IndexError, "Boost factor must be a positive number"
      end

      where_token = find_last_where_token
      where_token.boost = boost

      self
    end

    def fuzzy(fuzzy)
      if (fuzzy < 0) || (fuzzy > 1)
        raise IndexError, "Fuzzy distance must be between 0.0 and 1.0"
      end

      where_token = find_last_where_token
      where_token.fuzzy = fuzzy

      self
    end

    def proximity(proximity)
      if proximity < 1
        raise IndexError, "Proximity distance must be a positive number"
      end

      where_token = find_last_where_token
      where_token.proximity = proximity

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

    def order_by_score
      assert_no_raw_query
      @order_by_tokens.add_last(OrderByToken.score_ascending)

      self
    end

    def order_by_score_descending
      assert_no_raw_query
      @order_by_tokens.add_last(OrderByToken.score_descending)

      self
    end

    def search(field_name, search_terms_parameter_name, operator = SearchOperator::Or)
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed(field_name)

      @where_tokens.add_last(WhereToken.search(field_name, search_terms_parameter_name, operator))

      self
    end

    def intersect
      @last_token = @where_tokens.last

      unless (@last_token.is_a?(WhereToken) || @last_token.is_a?(CloseSubclauseToken))
        raise "Cannot add INTERSECT at this point."
      end

      @is_intersect = true
      @where_tokens.add_last(IntersectMarkerToken.instance)

      self
    end

    def distinct
      if @is_distinct
        raise "This is already a distinct query."
      end

      @is_distinct = true
      @select_tokens.add_first(DistinctToken.instance)

      self
    end

    def group_by(field_name, *field_names)
      unless @from_token.is_dynamic
        raise "GroupBy only works with dynamic queries."
      end

      assert_no_raw_query
      @is_group_by = true

      fields = [field_name]

      if field_names.is_a?(Array)
        fields = fields.concat(field_names)
      end

      fields.each do |field|
        field = ensure_valid_field_name(field)
        @group_by_tokens.add_last(GroupByToken.create(field))
      end

      self
    end

    def group_by_key(field_name, projected_name = nil)
      assert_no_raw_query
      @is_group_by = true

      if !projected_name.nil? && @alias_to_group_by_field_name.key?(projected_name)
        field_already_projected = @alias_to_group_by_field_name[projected_name]

        if field_name.nil? || field_name.empty? || (field_name == field_already_projected)
          field_name = field_already_projected
        end
      end

      @select_tokens.add_last(GroupByKeyToken.create(field_name, projected_name))

      self
    end

    def group_by_sum(field_name, projected_name = nil)
      assert_no_raw_query
      @is_group_by = true

      field_name = ensure_valid_field_name(field_name)
      @select_tokens.add_last(GroupBySumToken.create(field_name, projected_name))

      self
    end

    def group_by_count(projected_name = nil)
      assert_no_raw_query
      @is_group_by = true

      @select_tokens.add_last(GroupByCountToken.create(projected_name))

      self
    end

    def where_true
      append_operator_if_needed(@where_tokens)
      negate_if_needed

      @where_tokens.add_last(TrueToken.instance)

      self
    end

    def within_radiusof(field_name, radius_parameter_name, latitude_parameter_name,
                        longitude_parameter_name, radius_units = SpatialUnits::Kilometers,
                        dist_error_percent = SpatialConstants::DefaultDistanceErrorPct
    )
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed

      @where_tokens.add_last(WhereToken.within(
        field_name, ShapeToken.circle(
          radius_parameter_name,
          latitude_parameter_name,
          longitude_parameter_name,
          radius_units),
        dist_error_percent)
      )

      self
    end

    def spatial(field_name, shape_wkt_parameter_name_or_criteria,
                relation = nil, dist_error_percent = nil
    )
      criteria = shape_wkt_parameter_name_or_criteria
      field_name = ensure_valid_field_name(field_name)

      append_operator_if_needed(@where_tokens)
      negate_if_needed

      if shape_wkt_parameter_name_or_criteria.is_a?(SpatialCriteria)
        @where_tokens.add_last(criteria.to_query_token(field_name){ yield })
      else
        shape_wkt_parameter_name = shape_wkt_parameter_name_or_criteria
        relation = relation

        criteria = WktCriteria.new(nil, relation, dist_error_percent)
        @where_tokens.add_last(criteria.to_query_token(field_name){ shape_wkt_parameter_name })
      end

      self
    end

    def order_by_distance(field_name, latitude_or_shape_wkt_parameter_name, longitude_parameter_name = nil)
      @order_by_tokens.add_last(OrderByToken.create_distance_ascending(field_name, latitude_or_shape_wkt_parameter_name, longitude_parameter_name))

      self
    end

    def order_by_distance_descending(field_name, latitude_or_shape_wkt_parameter_name, longitude_parameter_name = nil)
      @order_by_tokens.add_last(OrderByToken.create_distance_descending(field_name, latitude_or_shape_wkt_parameter_name, longitude_parameter_name))

      self
    end

    def to_string
      unless @query_raw.nil?
        return @query_raw
      end

      unless @current_clause_depth == 0
        raise "A clause was not closed correctly within this query, current clause "\
              "depth = #{@current_clause_depth}"
      end

      query_text = StringBuilder.new

      build_from(query_text)
      build_group_by(query_text)
      build_where(query_text)
      build_order_by(query_text)
      build_select(query_text)
      build_include(query_text)

      query_text.to_string
    end

    protected
    def ensure_valid_field_name(field_name, is_nested_path = false)
      result = {
        original_field_name: field_name,
        escaped_field_name: StringUtilities.escape_if_necessary(field_name)
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
        token = QueryOperatorToken.or
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

    def find_last_where_token
      last_token = @where_tokens.last
      where_token = nil

      unless last_token.nil?
        where_token = last_token.value
      end

      unless where_token.is_a?(WhereToken)
        raise "Missing where clause"
      end

      where_token
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
      unless @query_raw.nil?
        raise "RawQuery was called, cannot modify this query by calling on operations that "\
              "would modify the query (such as Where, Select, OrderBy, GroupBy, etc)"
      end
    end

    def build_from(writer)
      @from_token.write_to(writer)
    end

    def build_order_by(writer)
      tokens = @order_by_tokens

      unless tokens.count > 0
        return
      end

      writer
        .append(" ")
        .append(QueryKeyword::Order)
        .append(" ")
        .append(QueryKeyword::By)
        .append(" ")

      tokens.each do |item|
        unless item.first
          writer.append(", ")
        end

        item.value.write_to(writer)
      end
    end

    def build_group_by(writer)
      tokens = @group_by_tokens

      unless tokens.count > 0
        return
      end

      writer
        .append(" ")
        .append(QueryKeyword::Group)
        .append(" ")
        .append(QueryKeyword::By)
        .append(" ")

      tokens.each do |item|
        unless item.first
          writer.append(", ")
        end

        item.value.write_to(writer)
      end
    end

    def build_select(writer)
      tokens = @select_tokens

      unless tokens.count > 0
        return
      end

      writer
        .append(" ")
        .append(QueryKeyword::Select)
        .append(" ")

      if (1 == tokens.count) && tokens.first.value.is_a?(DistinctToken)
        tokens.first.value.writeTo(writer)
        writer.append(" *")

        return
      end

      tokens.each do |item|
        is_first = item.first
        previous_token = is_first ? nil : item.previous.value

        if !is_first && !previous_token.is_a?(DistinctToken)
          writer.append(",")
        end

        self.class.add_space_if_needed(previous_token, item.value, writer)
        item.value.write_to(writer)
      end
    end

    def build_include(writer)
      if @includes.nil? || (@includes.size == 0)
        return
      end

      writer
        .append(" ")
        .append(QueryKeyword::Include)
        .append(" ")

      @includes.each_with_index do |include, index|
        required_quotes = false

        unless index == 0
          writer.append(",")
        end

        include.chars.each do |ch|
          if !ch.alnum?  && !["_", "."].include?(ch)
            required_quotes = true
            break
          end
        end

        if required_quotes
          writer
            .append("'")
            .append(include.gsub(/'/, "\\'"))
            .append("'")
        else
          writer.append(include)
        end
      end
    end

    def build_where(writer)
      tokens = @where_tokens

      if tokens.nil? || (tokens.count == 0)
        return
      end

      writer
        .append(" ")
        .append(QueryKeyword::Where)
        .append(" ")

      if @is_intersect
        writer.append("intersect(")
      end

      tokens.each do |item|
        is_first = item.first
        previous_token = is_first ? nil : item.previous.value

        self.class.add_space_if_needed(previous_token, item.value, writer)
        item.value.write_to(writer)
      end

      if @is_intersect
        writer
          .append(") ")
      end
    end

    def self.add_space_if_needed(previous_token, current_token, writer)
      if previous_token.nil?
        return
      end

      if previous_token.is_a?(OpenSubclauseToken) ||
        current_token.is_a?(CloseSubclauseToken)
        current_token.is_a?(IntersectMarkerToken)
        return
      end

      writer.append(" ")
    end
  end
end
