require 'digest'
require 'active_support/inflector'
require 'documents/query/query_builder'
require 'utilities/observable'

module RavenDB

  class IndexQuery
    DefaultTimeout = 15 * 1000
    DefaultPageSize = 2 ** 31 - 1

    attr_accessor :start, :page_size
    attr_reader :query, :query_parameters, :wait_for_non_stale_results,
                :wait_for_non_stale_results_as_of_now, :wait_for_non_stale_results_timeout

    def initialize(query = '', query_parameters = {}, page_size = DefaultPageSize, skipped_results = 0, options = {})
      @query = query
      @query_parameters = query_parameters || {}
      @page_size = page_size || DefaultPageSize
      @start = skipped_results || 0
      @cut_off_etag = options[:cut_off_etag] || nil
      @wait_for_non_stale_results = options[:wait_for_non_stale_results] || false
      @wait_for_non_stale_results_as_of_now = options[:wait_for_non_stale_results_as_of_now] || false
      @wait_for_non_stale_results_timeout = options[:wait_for_non_stale_results_timeout] || nil

      if !@page_size.is_a?(Numeric)
        @page_size = DefaultPageSize
      end

      if (@wait_for_non_stale_results ||
          @wait_for_non_stale_results_as_of_now) &&
         !@wait_for_non_stale_results_timeout

        @wait_for_non_stale_results_timeout = DefaultTimeout
      end
    end

    def query_hash
      buffer = "#{@query}#{@page_size}#{@start}"
      buffer = buffer + (@wait_for_non_stale_results ? "1" : "0")
      buffer = buffer + (@wait_for_non_stale_results_as_of_now ? "1" : "0")

      if @wait_for_non_stale_results
        buffer = buffer + "#{@wait_for_non_stale_results_timeout}"
      end  

      Digest::SHA256.hexdigest(buffer)
    end  

    def to_json
      json = {
        "Query" => @query,
        "QueryParameters" => @query_parameters,
      }

      if !@start.nil?
          json["Start"] = @start
      end

      if !@page_size.nil?
        json["PageSize"] = @page_size
      end

      if !@cut_off_etag.nil?
        json["CutoffEtag"] = @cut_off_etag
      end

      if !@wait_for_non_stale_results.nil?
        json["WaitForNonStaleResults"] = true
      end

      if !@wait_for_non_stale_results_as_of_now.nil?
        json["WaitForNonStaleResultsAsOfNow"] = true
      end

      if (@wait_for_non_stale_results ||
          @wait_for_non_stale_results_as_of_now) &&
         !@wait_for_non_stale_results_timeout.nil?
         json["WaitForNonStaleResultsTimeout"] = @wait_for_non_stale_results_timeout.to_s

      end

      json
    end  
  end

  class QueryOperationOptions
    attr_reader :allow_stale, :stale_timeout, :max_ops_per_sec, :retrieve_details

    def initialize(allow_stale = true, stale_timeout = nil, max_ops_per_sec = nil, retrieve_details = false)
      @allow_stale = allow_stale
      @stale_timeout = stale_timeout
      @max_ops_per_sec = max_ops_per_sec
      @retrieve_details = retrieve_details
    end
  end

  class DocumentQueryBase
    include Observable

    attr_accessor :take, :skip
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

      @document_type = document_type
      @id_property_name = conventions.get_id_property_name(document_type)
      @builder = QueryBuilder.new(@index_name, @collection_name, @id_property_name)
    end

    def conventions
      @session.conventions
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