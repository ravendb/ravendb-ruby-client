require "date"
require "active_support/core_ext/object/deep_dup"
require "active_support/inflector"
require "database/exceptions"
require "utilities/type_utilities"
require "utilities/json"

module RavenDB
  class DocumentConventions
    @max_number_of_request_per_session = 30
    @request_timeout = 30
    @default_use_optimistic_concurrency = true
    @max_length_of_query_using_get_url = 1024 + 512
    @identity_parts_separator = "/".freeze

    class << self
      attr_accessor :max_number_of_request_per_session
      attr_accessor :request_timeout
      attr_accessor :default_use_optimistic_concurrency
      attr_accessor :max_length_of_query_using_get_url
      attr_accessor :identity_parts_separator
    end

    attr_accessor :set_id_only_if_property_is_defined, :disable_topology_updates, :serializers

    def initialize
      @set_id_only_if_property_is_defined = false
      @disable_topology_updates = false
      @_document_id_resolvers = []
      @_id_properties_names_cache = {}
      @serializers = []
    end

    def empty_collection
      "@empty"
    end

    def empty_change_vector
      nil
    end

    def add_attribute_serializer(serializer)
      unless serializer.is_a?(AttributeSerializer)
        raise ArgumentError,
              "Serializer shoulde be class instance derived from RavenDB::AttributeSerializer"
      end

      @serializers.push(serializer)
    end

    def add_id_property_resolver(&resolver)
      return unless block_given?

      @_document_id_resolvers.push(resolver)
    end

    def get_collection_name(document_class_or_document_type)
      document_type = document_class_or_document_type

      if document_class_or_document_type.is_a?(Class)
        document_type = get_document_type(document_class_or_document_type)
      end

      document_type.pluralize
    end

    def get_document_type(document_class)
      unless document_class.is_a?(Class)
        raise "Invalid argument passed. Should be an document class constructor"
      end

      document_class.name.to_s
    end

    def get_document_constructor(document_type)
      unless document_type.is_a?(String)
        raise "Invalid argument passed. Should be an string"
      end

      Object.const_get(document_type)
    end

    def get_id_property_name(document_or_class, document = nil)
      id_property = "id"
      document_type = nil
      document_class = nil
      document_instance = document

      if TypeUtilities.document?(document_or_class)
        document_class = document_or_class.class
        document_instance = document_or_class
      elsif document_or_class.is_a?(Class)
        document_class = document_or_class
      elsif document_or_class.is_a?(String)
        document_type = document_or_class
      end

      if document_type.nil? && !document_class.nil?
        document_type = document_class.name
      end

      if document_type.nil?
        raise "Invalid argument passed. Should be an document, class constructor or document type name"
      end

      if @_id_properties_names_cache.key?(document_type)
        id_property = @_id_properties_names_cache[document_type]
      else
        found_id_property = nil

        @_document_id_resolvers.each do |resolver|
          begin
            found_id_property = resolver.call(
              document_type: document_type,
              document_class: document_class,
              document: document_instance
            ) || nil
          rescue StandardError
            found_id_property = nil
          end

          break unless found_id_property.nil?
        end

        unless found_id_property.nil?
          id_property = found_id_property
          @_id_properties_names_cache[document_type] = id_property
        end
      end

      id_property
    end

    def convert_to_document(raw_entity, document_type = nil, nested_object_types = {})
      unless raw_entity.is_a?(Hash)
        raise "Invalid raw_entity passed. Should be an hash"
      end

      metadata = raw_entity.fetch("@metadata", {})
      doc_type = document_type || metadata["Raven-Ruby-Type"]

      if document_type.is_a?(Class)
        doc_type = document_type.name
      end

      if doc_type.nil?
        doc_type = "Object"
      end

      metadata = raw_entity.fetch("@metadata", {})
      original_metadata = metadata.deep_dup
      doc_ctor = get_document_constructor(doc_type)
      attributes = TypeUtilities.omit_keys(raw_entity, ["@metadata"])
      document = JsonSerializer.from_json(doc_ctor.new, attributes, metadata, nested_object_types, self)

      set_id_on_document(document, metadata["@id"] || nil)

      {
        raw_entity: raw_entity,
        document: document,
        metadata: metadata,
        original_metadata: original_metadata,
        document_type: doc_type
      }
    end

    def convert_to_raw_entity(document)
      id_property = get_id_property_name(document)
      raw_entity = JsonSerializer.to_json(document, self)

      if raw_entity.key?(id_property)
        raw_entity.delete_if { |key| id_property == key }
      end

      raw_entity
    end

    def try_fetch_results(command_response)
      unless command_response.is_a?(Hash)
        raise "Invalid command_response passed. Should be an hash"
      end

      response_results = []

      if command_response.key?("Results") && command_response["Results"].is_a?(Array)
        response_results = command_response["Results"]
      end

      response_results
    end

    def try_fetch_includes(command_response)
      unless command_response.is_a?(Hash)
        raise "Invalid command_response passed. Should be an hash"
      end

      response_includes = []

      if command_response.key?("Includes")
        if command_response["Includes"].is_a?(Array)
          response_includes = command_response["Includes"]
        elsif command_response["Includes"].is_a?(Hash)
          response_includes = command_response["Includes"].values
        end
      end

      response_includes
    end

    def check_is_projection?(response_item)
      unless response_item.is_a?(Hash)
        raise "Invalid command_response passed. Should be an hash"
      end

      if response_item.key?("@metadata")
        metadata = response_item["@metadata"]

        if metadata.is_a?(Hash) && metadata.key?("@projection")
          return metadata["@projection"] || false
        end
      end

      false
    end

    def set_id_on_document(document, id)
      metadata = {}
      id_property = "@#{get_id_property_name(document)}"

      if !@set_id_only_if_property_is_defined || document.instance_variable_defined?(id_property)
        document.instance_variable_set(id_property, id)
      end

      if document.instance_variable_defined?("@metadata")
        metadata = document.instance_variable_get("@metadata")
      end

      metadata["@id"] = id
      document.instance_variable_set("@metadata", metadata)
      document
    end

    def get_id_from_document(document)
      id = nil
      id_property = "@#{get_id_property_name(document)}"

      if document.instance_variable_defined?(id_property)
        id = document.instance_variable_get(id_property)
      end

      if id.nil? && document.instance_variable_defined?("@metadata")
        metadata = document.instance_variable_get("@metadata")
        id = metadata["@id"]
      end

      id || nil
    end

    def get_type_from_document(document)
      unless TypeUtilities.document?(document)
        raise "Invalid argument passed. Should be an document"
      end

      metadata = {}

      if document.instance_variable_defined?("@metadata")
        metadata = document.instance_variable_get("@metadata")
      end

      if metadata.key?("Raven-Ruby-Type")
        return metadata["Raven-Ruby-Type"]
      end

      if metadata.key?("@collection") && empty_collection != metadata["@collection"]
        return metadata["@collection"].singularize.capitalize
      end

      get_document_type(document.class)
    end

    def build_default_metadata(document)
      metadata = {}
      nested_types = {}

      unless TypeUtilities.document?(document)
        raise "Invalid argument passed. Should be an document"
      end

      if document.instance_variable_defined?("@metadata")
        metadata = document.instance_variable_get("@metadata")
      end

      metadata = metadata.merge(
        "Raven-Ruby-Type" => get_type_from_document(document),
        "@collection" => get_collection_name(document.class)
      )

      document.instance_variables.each do |instance_variable|
        value_for_check = document.instance_variable_get(instance_variable)

        if value_for_check.is_a?(Array) && !value_for_check.empty?
          value_for_check = value_for_check.first
        end

        unless (nested_type = find_nested_type(value_for_check)).nil?
          nested_types[instance_variable.to_s.delete("@")] = nested_type
        end
      end

      unless nested_types.empty?
        metadata["@nested_object_types"] = nested_types
      end

      metadata
    end

    protected

    def find_nested_type(instance_variable_value)
      if instance_variable_value.is_a?(Date) || instance_variable_value.is_a?(DateTime)
        return "date"
      end

      if TypeUtilities.document?(instance_variable_value)
        return get_document_type(instance_variable_value.class)
      end

      nil
    end
  end
end
