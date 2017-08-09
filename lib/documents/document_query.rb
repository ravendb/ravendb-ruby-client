import 'constants/documents'

module RavenDB
  class IndexDefinition
    @maps = []
    @index_id = 0
    @is_test_index = false
    @reduce = nil
    @lock_mode = nil
    @priority = nil
    @configuration = {}
    @fields = {}
    @_name = nil

    constructor(name, index_map, configuration = nil, init_options = {})
      @_name = name
      @configuration = configuration || {}
      @reduce = initOptions["reduce"] || 0
      @index_id = initOptions["index_id"] || nil
      @lock_mode = initOptions["lock_mod"] || nil
      @priority = initOptions["priority"] || nil
      @is_test_index = initOptions["is_test_index"] || false
      @fields = initOptions["fields"] || {}
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

      if @reduce
        result += 'Reduce';
      end

      return result
    end

    def is_map_reduce
      return @reduce || false
    end

    def map
      if @maps.length
        return @maps.first
      end

      return nil
    end

    def map=(value)
      if @maps.size
        @maps.pop()
      end

      @maps.push(value)
    end

    def to_json
      return {
        "Configuration" => @configuration,
        "Fields" => @fields.map({ |field| field.to_json }),
        "IndexId" => @index_id,
        "IsTestIndex" => @is_test_index,
        "LockMode" => @lock_mode || nil,
        "Maps" => @maps,
        "Name" => @_name,
        "Reduce" => @reduce,
        "OutputReduceToCollection" => nil,
        "Priority" => @priority || nil,
        "Type" => @type
      }
    end
  end

  class IndexFieldOptions
    @sort_options = nil
    @indexing = nil
    @storage = nil
    @term_vector = nil
    @suggestions = nil
    @analyzer = nil

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
    @start = 0
    @page_size = 128
    @fetch = []
    @sort_hints = []
    @sort_fields = []
    @query = ''
    @default_operator = nil
    @wait_for_non_stale_results = false
    @wait_for_non_stale_results_timeout = nil

    attr_accessor :start, :page_size
    attr_reader :default_operator, :query, :fetch, :sort_hints, :sort_fields, :wait_for_non_stale_results, :wait_for_non_stale_results_timeout

    def initialize(query = '', page_size = 128, skipped_results = 0, default_operator = nil, options = {})
      @query = query;
      @page_size = page_size || 128
      @start = skipped_results || 0
      @fetch = options["fetch"] || []
      @sort_hints = options["sort_hints"] || []
      @sort_fields = options["sort_fields"] || []
      @defaultOperator = options["default_operator"] || RQLJoinOperator::OR
      @wait_for_non_stale_results = options["wait_for_non_stale_results"] || false
      @wait_for_non_stale_results_timeout = options["wait_for_non_stale_results_timeout"] || nil

      if @wait_for_non_stale_results && !@wait_for_non_stale_results_timeout
        @wait_for_non_stale_results_timeout = 15 * 60
      end
    end
  end
end