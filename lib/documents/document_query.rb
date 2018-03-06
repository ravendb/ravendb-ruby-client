require "date"
require "digest"
require "active_support/inflector"
require "constants/documents"
require "database/commands"
require "database/exceptions"
require "documents/query/index_query"
require "documents/query/query_builder"
require "utilities/observable"
require "utilities/type_utilities"

module RavenDB
  class DocumentQueryBase
    include Observable

    def self.create(session, request_executor, options = nil)
      with_statistics = false
      index_name = nil
      collection = nil
      document_type = nil
      index_query_options = {}
      nested_object_types = {}

      if options.is_a?(Hash)
        with_statistics = options[:with_statistics] || false
        index_name = options[:index_name] || nil
        collection = options[:collection] || "@all_docs"
        document_type = options[:document_type] || nil
        index_query_options = options[:index_query_options] || {}
        nested_object_types = options[:nested_object_types] || {}
      end

      new(
        session, request_executor, collection, index_name, document_type,
        nested_object_types, with_statistics, index_query_options
      )
    end

    def initialize(session, request_executor, collection = nil, index_name = nil, document_type_or_class = nil?,
                   nested_object_types = nil, with_statistics = false, index_query_options = {})
      document_type = nil

      @session = session
      @index_query_options = index_query_options
      @with_statistics = with_statistics
      @request_executor = request_executor
      @nested_object_types = nested_object_types || {}
      @query_parameters = {}
      @id_property_name = "id"
      @take = nil
      @skip = nil

      if !index_name.nil?
        @collection_name = nil
        @index_name = index_name
      else
        @index_name = nil
        @collection_name = collection || "@all_docs"
      end

      if !document_type_or_class.nil?
        document_type = document_type_or_class

        if document_type.is_a?(Class)
          document_type = document_type.name
        end
      elsif !collection.nil?
        document_type = collection.singularize.upcase_first
      end

      unless document_type.nil?
        @id_property_name = conventions.get_id_property_name(document_type)
      end

      @document_type = document_type
      @builder = QueryBuilder.new(@index_name, @collection_name, @id_property_name)
    end

    def conventions
      @session.conventions
    end

    def wait_for_non_stale_results
      @index_query_options = @index_query_options.merge(
        cut_off_etag: nil,
        wait_for_non_stale_results: true,
        wait_for_non_stale_results_timeout: IndexQuery::DefaultTimeout
      )

      self
    end

    def wait_for_non_stale_results_as_of(cut_off_etag, wait_timeout = nil)
      @index_query_options = @index_query_options.merge(
        cut_off_etag: cut_off_etag,
        wait_for_non_stale_results: true,
        wait_for_non_stale_results_timeout: wait_timeout || IndexQuery::DefaultTimeout
      )

      self
    end

    def wait_for_non_stale_results_as_of_now(wait_timeout = nil)
      @index_query_options = @index_query_options.merge(
        cut_off_etag: nil,
        wait_for_non_stale_results: true,
        wait_for_non_stale_results_as_of_now: true,
        wait_for_non_stale_results_timeout: wait_timeout || IndexQuery::DefaultTimeout
      )

      self
    end

    def take(docs_count)
      @take = docs_count

      self
    end

    def skip(skip_count)
      @skip = skip_count

      self
    end

    def get_index_query
      skip = 0
      take = IndexQuery::DefaultPageSize
      query = @builder.to_string

      unless @skip.nil?
        skip = @skip
      end

      unless @take.nil?
        take = @take
      end

      IndexQuery.new(query, @query_parameters, take, skip, @index_query_options)
    end

    def single
      take = @take
      skip = @skip
      with_statistics = @with_statistics

      @take = 2
      @skip = 0
      @with_statistics = false

      response = execute_query
      results = convert_response_to_documents(response)
      result = nil

      if results.is_a?(Array) && !results.empty?
        result = results.first
      end

      if results.size != 1
        error_message = if results.length > 1
                          "There's more than one result corresponding to given query criteria."
                        else
                          "There's no results corresponding to given query criteria."
                        end

        raise error_message
      end

      @take = take
      @skip = skip
      @with_statistics = with_statistics
      result
    end

    def first
      take = @take
      skip = @skip
      with_statistics = @with_statistics

      @take = 1
      @skip = 0
      @with_statistics = false

      response = execute_query
      results = convert_response_to_documents(response)
      result = nil

      if results.is_a?(Array) && !results.empty?
        result = results.first
      end

      @take = take
      @skip = skip
      @with_statistics = with_statistics
      result
    end

    def count
      take = @take
      skip = @skip
      with_statistics = @with_statistics

      @take = 0
      @skip = 0
      @with_statistics = false

      response = execute_query
      result = 0

      if response.is_a?(Hash) && response.key?("TotalResults")
        result = response["TotalResults"] || 0
      end

      @take = take
      @skip = skip
      @with_statistics = with_statistics
      result
    end

    def all
      results = []
      response = execute_query

      if response.is_a?(Hash)
        results = convert_response_to_documents(response)
      end

      results
    end

    protected

    def execute_query
      emit(RavenServerEvent::EVENT_DOCUMENTS_QUERIED)

      query = get_index_query
      query_command = QueryCommand.new(conventions, query)
      response = @request_executor.execute(query_command)

      if response.nil? || !response
        {
          "Results" => [],
          "Includes" => []
        }
      elsif response["IsStale"]
        raise ErrorResponseException, "The index is still stale after reached the timeout"
      else
        response
      end
    end

    def convert_response_to_documents(response)
      query_result = []
      response_results = conventions.try_fetch_results(response)

      if response_results.is_a?(Array) && !response_results.empty?
        results = []
        response_includes = conventions.try_fetch_includes(response)

        response_results.each do |result|
          conversion_result = conventions.convert_to_document(
            result, @document_type, @nested_object_types
          )

          results.push(conversion_result[:document])

          unless conventions.check_is_projection?(result)
            emit(RavenServerEvent::EVENT_DOCUMENT_FETCHED, conversion_result)
          end
        end

        if response_includes.is_a?(Array) && !response_includes.empty?
          emit(RavenServerEvent::EVENT_INCLUDES_FETCHED, response_includes)
        end

        query_result = results

        if @with_statistics
          query_result = {
            results: query_result,
            response: results
          }
        end
      end

      query_result
    end
  end

  class RawDocumentQuery < DocumentQueryBase
    def raw_query(query)
      @builder.raw_query(query)

      self
    end

    def add_parameter(name, value)
      @query_parameters[name] = value

      self
    end
  end

  class DocumentQuery < DocumentQueryBase
    attr_reader :index_name, :collection_name

    def not
      negate_next
      self
    end

    def is_dynamic_map_reduce
      @builder.is_dynamic_map_reduce
    end

    def select_fields(fields, projections = nil)
      @builder.select_fields(fields, projections)

      self
    end

    def get_projection_fields
      @builder.get_projections_fields
    end

    def random_ordering(seed = nil)
      @builder.random_ordering(seed)

      self
    end

    def custom_sort_using(type_name, descending = nil)
      @builder.custom_sort_using(type_name, descending)

      self
    end

    def include(path)
      @builder.include(path)

      self
    end

    def using_default_operator(operator)
      @builder.using_default_operator(operator)

      self
    end

    def where_equals(where_params_or_field_name, value = nil, exact = false)
      where_params = where_params_or_field_name
      field_name = where_params_or_field_name

      if field_name.is_a?(String)
        return where_equals(
          field_name: field_name,
          value: value,
          exact: exact
        )
      end

      transformed_value = transform_value(where_params)
      @builder.where_equals(parametrize(where_params, add_query_parameter(transformed_value)))

      self
    end

    def where_not_equals(where_params_or_field_name, value = nil, exact = false)
      where_params = where_params_or_field_name
      field_name = where_params_or_field_name

      if field_name.is_a?(String)
        return where_not_equals(
          field_name: field_name,
          value: value,
          exact: exact
        )
      end

      transformed_value = transform_value(where_params)
      @builder.where_not_equals(parametrize(where_params, add_query_parameter(transformed_value)))

      self
    end

    def open_subclause
      @builder.open_subclause

      self
    end

    def close_subclause
      @builder.close_subclause

      self
    end

    def negate_next
      @builder.negate_next

      self
    end

    def where_in(field_name, values, exact = false)
      transformed_values = transform_values_array(field_name, values)
      @builder.where_in(field_name, add_query_parameter(transformed_values), exact)

      self
    end

    def where_starts_with(field_name, value)
      transformed_value = transform_value(
        field_name: field_name,
        value: value,
        allow_wildcards: true
      )

      @builder.where_starts_with(field_name, add_query_parameter(transformed_value))
      self
    end

    def where_ends_with(field_name, value)
      transformed_value = transform_value(
        field_name: field_name,
        value: value,
        allow_wildcards: true
      )

      @builder.where_ends_with(field_name, add_query_parameter(transformed_value))
      self
    end

    def where_between(field_name, from, to, exact = nil)
      transformed_from = "*"
      transformed_to = "NULL"

      unless from.nil?
        transformed_from = transform_value(
          field_name: field_name,
          value: from,
          exact: exact
        )
      end

      unless to.nil?
        transformed_to = transform_value(
          field_name: field_name,
          value: to,
          exact: exact
        )
      end

      @builder.where_between(
        field_name, add_query_parameter(transformed_from),
        add_query_parameter(transformed_to), exact
      )

      self
    end

    def where_greater_than(field_name, value, exact = nil)
      transformed_value = "*"

      unless value.nil?
        transformed_value = transform_value(
          field_name: field_name,
          value: value,
          exact: exact
        )
      end

      @builder.where_greater_than(field_name, add_query_parameter(transformed_value), exact)
      self
    end

    def where_greater_than_or_equal(field_name, value, exact = nil)
      transformed_value = "*"

      unless value.nil?
        transformed_value = transform_value(
          field_name: field_name,
          value: value,
          exact: exact
        )
      end

      @builder.where_greater_than_or_equal(field_name, add_query_parameter(transformed_value), exact)
      self
    end

    def where_less_than(field_name, value, exact = nil)
      transformed_value = "NULL"

      unless value.nil?
        transformed_value = transform_value(
          field_name: field_name,
          value: value,
          exact: exact
        )
      end

      @builder.where_less_than(field_name, add_query_parameter(transformed_value), exact)
      self
    end

    def where_less_than_or_equal(field_name, value, exact = nil)
      transformed_value = "NULL"

      unless value.nil?
        transformed_value = transform_value(
          field_name: field_name,
          value: value,
          exact: exact
        )
      end

      @builder.where_less_than_or_equal(field_name, add_query_parameter(transformed_value), exact)
      self
    end

    def where_exists(field_name)
      @builder.where_exists(field_name)

      self
    end

    def and_also
      @builder.and_also

      self
    end

    def or_else
      @builder.or_else

      self
    end

    def boost(boost)
      @builder.boost(boost)

      self
    end

    def fuzzy(fuzzy)
      @builder.fuzzy(fuzzy)

      self
    end

    def proximity(proximity)
      @builder.proximity(proximity)

      self
    end

    def order_by(field, ordering = nil)
      @builder.order_by(field, ordering)

      self
    end

    def order_by_descending(field, ordering = nil)
      @builder.order_by_descending(field, ordering)

      self
    end

    def order_by_score
      @builder.order_by_score

      self
    end

    def order_by_score_descending
      @builder.order_by_score_descending

      self
    end

    def search(field_name, search_terms, operator = SearchOperator::Or)
      @builder.search(field_name, add_query_parameter(search_terms), operator)

      self
    end

    def intersect
      @builder.intersect

      self
    end

    def distinct
      @builder.distinct

      self
    end

    def contains_any(field_name, values)
      transformed_values = transform_values_array(field_name, values)

      unless transformed_values.empty?
        @builder.where_in(field_name, add_query_parameter(transformed_values))
      end

      self
    end

    def contains_all(field_name, values)
      transformed_values = transform_values_array(field_name, values)

      unless transformed_values.empty?
        @builder.where_all_in(field_name, add_query_parameter(transformed_values))
      end

      self
    end

    def group_by(field_name, *field_names)
      fields = [field_name]

      unless field_names.empty?
        fields = fields.concat(field_names)
      end

      @builder.send(:group_by, *fields)
      self
    end

    def group_by_key(field_name, projected_name = nil)
      @builder.group_by_key(field_name, projected_name)

      self
    end

    def group_by_sum(field_name, projected_name = nil)
      @builder.group_by_sum(field_name, projected_name)

      self
    end

    def group_by_count(projected_name = nil)
      @builder.group_by_count(projected_name)

      self
    end

    def where_true
      @builder.where_true

      self
    end

    def within_radius_of(field_name, radius, latitude, longitude, radius_units = nil, dist_error_percent = nil)
      @builder.within_radius_of(
        field_name, add_query_parameter(radius), add_query_parameter(latitude),
        add_query_parameter(longitude), radius_units, dist_error_percent
      )

      self
    end

    def spatial(field_name, shape_wkt_or_criteria, relation = nil, dist_error_percent = nil)
      criteria = shape_wkt_or_criteria
      shape_wkt = shape_wkt_or_criteria

      if criteria.is_a?(SpatialCriteria)
        @builder.spatial(field_name, criteria) do |parameter_value|
          add_query_parameter(parameter_value)
        end
      else
        @builder.spatial(field_name, add_query_parameter(shape_wkt), relation, dist_error_percent)
      end

      self
    end

    def order_by_distance(field_name, latitude_or_shape_wkt, longitude = nil)
      shape_wkt = latitude_or_shape_wkt
      latitude = latitude_or_shape_wkt

      if longitude.nil?
        @builder.order_by_distance(field_name, add_query_parameter(shape_wkt))
      else
        @builder.order_by_distance(field_name, add_query_parameter(latitude), add_query_parameter(longitude))
      end

      self
    end

    def order_by_distance_descending(field_name, latitude_or_shape_wkt, longitude = nil)
      shape_wkt = latitude_or_shape_wkt
      latitude = latitude_or_shape_wkt

      if longitude.nil?
        @builder.order_by_distance_descending(field_name, add_query_parameter(shape_wkt))
      else
        @builder.order_by_distance_descending(field_name, add_query_parameter(latitude), add_query_parameter(longitude))
      end

      self
    end

    protected

    def add_query_parameter(value_or_values)
      parameter_name = "p#{@query_parameters.size}".to_sym

      @query_parameters[parameter_name] = value_or_values
      parameter_name
    end

    def transform_value(where_params)
      value = where_params[:value]

      if value.nil?
        return nil
      end

      if value == ""
        return ""
      end

      if value.is_a?(Date) || value.is_a?(DateTime)
        return TypeUtilities.stringify_date(value)
      end

      unless (value == !!value) || value.is_a?(Numeric) || value.is_a?(String) ||
             value.is_a?(Date) || value.is_a?(DateTime)

        raise ArgumentError,
              "Invalid value passed to query condition. "\
              "Only integer / number / string / dates / bools and nil values are supported"
      end

      value
    end

    def transform_values_array(field_name, values)
      result = []
      unpacked = values.flatten

      unpacked.each do |value|
        nested_where_params = {
          field_name: field_name,
          value: value,
          allow_wildcards: true
        }

        result.push(transform_value(nested_where_params))
      end

      result
    end

    def parametrize(where_params, parameter_name)
      where_params.delete(:value)
      where_params[:parameter_name] = parameter_name

      where_params
    end
  end
end
