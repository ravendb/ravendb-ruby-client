require 'digest'
require 'constants/documents'
require 'constants/database'

module RavenDB
  class IndexDefinition
    def initialize(name, index_map, configuration = nil, init_options = {})
      @_name = name
      @configuration = configuration || {}
      @reduce = init_options["reduce"] || 0
      @index_id = init_options["index_id"] || nil
      @lock_mode = init_options["lock_mode"] || nil
      @priority = init_options["priority"] || nil
      @is_test_index = init_options["is_test_index"] || false
      @fields = init_options["fields"] || {}
      @maps = index_map.is_a?(Array) ? index_map : [index_map]
    end

    def name
      @_name
    end

    def type
      result = 'Map';

      if @_name && @_name.start_with?('Auto/')
        result = 'Auto' + result
      end

      if @reduce > 0
        result += 'Reduce';
      end

      return result
    end

    def is_map_reduce
      return @reduce > 0
    end

    def map
      @maps.length ? @maps.first : nil
    end

    def map=(value)
      if @maps.size
        @maps.pop()
      end

      @maps.push(value)
    end

    def to_json
      fields_json = {}
      
      @fields.each do |field, definition| 
        fields_json[field] = definition.to_json
      end  

      return {
        "Name" => @_name,
        "Maps" => @maps,
        "Type" => type,
        "LockMode" => @lock_mode || IndexLockMode::Unlock,
        "Priority" => @priority || IndexPriority::Normal,
        "Configuration" => @configuration,
        "Fields" => fields_json,
        "IndexId" => @index_id,
        "IsTestIndex" => @is_test_index,
        "Reduce" => @reduce,
        "OutputReduceToCollection" => nil        
      }
    end
  end

  class IndexFieldOptions
    def initialize(sort_options = nil, indexing = nil, storage = nil, suggestions = nil, term_vector = nil, analyzer = nil) 
      @sort_options = sort_options
      @indexing = indexing
      @storage = storage
      @suggestions = suggestions
      @term_vector = term_vector
      @analyzer = analyzer
    end

    def to_json
      return {
        "Analyzer" => @analyzer,
        "Indexing" => @indexing || nil,
        "Sort" => @sort_options || nil,
        "Spatial" => nil,
        "Storage" => @storage.nil? ? nil : (@storage ? "Yes" : "No"),
        "Suggestions" => @suggestions,
        "TermVector" => @term_vector || nil
      }
    end
  end

  class IndexQuery
    attr_accessor :start, :page_size
    attr_reader :default_operator, :query, :wait_for_non_stale_results, :wait_for_non_stale_results_timeout

    def initialize(query = '', page_size = 128, skipped_results = 0, options = {})
      @query = query;
      @page_size = page_size || 128
      @start = skipped_results || 0
      @wait_for_non_stale_results = options["wait_for_non_stale_results"] || false
      @wait_for_non_stale_results_timeout = options["wait_for_non_stale_results_timeout"] || nil

      if @wait_for_non_stale_results && !@wait_for_non_stale_results_timeout
        @wait_for_non_stale_results_timeout = 15 * 60
      end
    end

    def query_hash
      buffer = "#{@query}#{@page_size}#{@start}"
      buffer = buffer + (@wait_for_non_stale_results ? "1" : "0")

      if @wait_for_non_stale_results
        buffer = buffer + "#{@wait_for_non_stale_results_timeout}"
      end  

      Digest::SHA256.hexdigest(buffer)
    end  

    def to_json
      json = {
        "PageSize" => @page_size,
        "Query" => @query,
        "Start" => @start,
        "WaitForNonStaleResultsAsOfNow" => @wait_for_non_stale_results,
        "WaitForNonStaleResultsTimeout" => nil
      }

      if @wait_for_non_stale_results
        json["WaitForNonStaleResultsTimeout"] = "#{@wait_for_non_stale_results_timeout}"
      end

      json
    end  
  end
end