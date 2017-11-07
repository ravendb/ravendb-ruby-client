require 'digest'
require 'active_support/inflector'
require 'database/commands'
require 'database/exceptions'
require 'documents/query/index_query'
require 'documents/query/query_builder'
require 'utilities/observable'

module RavenDB
  class DocumentQueryBase
    include Observable

    attr_reader :index_name, :collection_name

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
        collection = options[:collection]  || '@all_docs'
        document_type = options[:document_type] || nil
        index_query_options = options[:index_query_options] || {}
        nested_object_types = options[:nested_object_types] || {}
      end

      self.new(
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
      @id_property_name = 'id'
      @take = nil
      @skip = nil

      if !index_name.nil?
        @collection_name = nil
        @index_name = index_name
      else
        @index_name = nil
        @collection_name = collection || '@all_docs'
      end

      if !document_type_or_class.nil?
        document_type = document_type_or_class

        if document_type.is_a?(Class)
          document_type = document_type.name
        end
      elsif !collection.nil?
        document_type = collection.singularize.capitalize
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
      @index_query_options = @index_query_options.merge({
        :cut_off_etag => nil,
        :wait_for_non_stale_results => true,
        :wait_for_non_stale_results_timeout => IndexQuery::DefaultTimeout
      })

      self
    end

    def wait_for_non_stale_results_as_of(cut_off_etag, wait_timeout = nil)
      @index_query_options = @index_query_options.merge({
        :cut_off_etag => cut_off_etag,
        :wait_for_non_stale_results => true,
        :wait_for_non_stale_results_timeout => wait_timeout || IndexQuery::DefaultTimeout
      })

      self
    end

    def wait_for_non_stale_results_as_of_now(wait_timeout = nil)
      @index_query_options = @index_query_options.merge({
        :cut_off_etag => nil,
        :wait_for_non_stale_results => true,
        :wait_for_non_stale_results_as_of_now => true,
        :wait_for_non_stale_results_timeout => wait_timeout || IndexQuery::DefaultTimeout
      })

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
        error_message = (results.length > 1) ?
          "There's more than one result corresponding to given query criteria." :
          "There's no results corresponding to given query criteria."

        raise InvalidOperationException, error_message
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
            :results => query_result,
            :response => results
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
end