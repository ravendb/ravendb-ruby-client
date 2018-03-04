require "constants/documents"
require "constants/database"

module RavenDB

  class IndexDefinition
    def initialize(name, index_map, configuration = nil, init_options = {})
      @_name = name
      @configuration = configuration || {}
      @reduce = init_options[:reduce] || 0
      @lock_mode = init_options[:lock_mode] || nil
      @priority = init_options[:priority] || nil
      @is_test_index = init_options[:is_test_index] || false
      @fields = init_options[:fields] || {}
      @maps = index_map.is_a?(Array) ? index_map : [index_map]
    end

    def name
      @_name
    end

    def type
      result = "Map"

      if @_name && @_name.start_with?("Auto/")
        result = "Auto" + result
      end

      if @reduce > 0
        result += "Reduce"
      end

      result
    end

    def is_map_reduce
      @reduce > 0
    end

    def map
      @maps.length ? @maps.first : nil
    end

    def map=(value)
      if @maps.size
        @maps.pop
      end

      @maps.push(value)
    end

    def to_json
      fields_json = {}

      @fields.each do |field, definition|
        fields_json[field] = definition.to_json
      end

      {
        "Configuration" => @configuration,
        "Fields" => fields_json,
        "IsTestIndex" => @is_test_index,
        "LockMode" => @lock_mode,
        "Maps" => @maps,
        "Name" => @_name,
        "Reduce" => @reduce,
        "OutputReduceToCollection" => nil,
        "Priority" => @priority || IndexPriority::Normal,
        "Type" => type
      }
    end
  end

  class IndexFieldOptions
    def initialize(indexing = nil, storage = nil, suggestions = nil, term_vector = nil, analyzer = nil)
      @indexing = indexing
      @storage = storage
      @suggestions = suggestions
      @term_vector = term_vector
      @analyzer = analyzer
    end

    def to_json
      {
        "Analyzer" => @analyzer,
        "Indexing" => @indexing || nil,
        "Spatial" => nil,
        "Storage" => @storage.nil? ? nil : (@storage ? "Yes" : "No"),
        "Suggestions" => @suggestions,
        "TermVector" => @term_vector || nil
      }
    end
  end

end