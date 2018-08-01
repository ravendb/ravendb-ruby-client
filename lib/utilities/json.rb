require "json"
require "net/http"
require "database/exceptions"
require "utilities/type_utilities"
require "active_support/hash_with_indifferent_access"

module Net
  class HTTPResponse
    def json(raise_when_invalid = true)
      json = body
      parsed = nil

      unless json.is_a? Hash
        begin
          if json.is_a?(String) && !json.empty?
            parsed = JSON.parse(json)
          end
        rescue StandardError
          if raise_when_invalid
            raise RavenDB::ErrorResponseException, "Not a valid JSON"
          end
        end
      end

      parsed
    end
  end
end

module RavenDB
  class AttributeSerializer
    def on_serialized(serialized)
    end

    def on_unserialized(serialized)
    end
  end

  class JsonSerializer
    def self.from_json(target, source = {}, metadata = {}, nested_object_types = {}, conventions = nil, parent_path = nil, key_mapper: nil)
      mappings = {}

      unless TypeUtilities.document?(target)
        raise "Invalid target passed. Should be a user-defined class instance"
      end

      unless source.is_a?(Hash)
        raise "Invalid source passed. Should be a Hash object"
      end

      source.delete("@id") if source.key?("@id")
      source.delete("@nested_object_types") if source.key?("@nested_object_types")

      if metadata.key?("@nested_object_types") &&
         metadata["@nested_object_types"].is_a?(Hash)
        mappings = mappings.merge(metadata["@nested_object_types"])
      end

      if nested_object_types.is_a?(Hash) && nested_object_types.size
        mappings = mappings.merge(nested_object_types)
      end

      current_metadata = {}

      if metadata.is_a?(Hash) && metadata.size
        if target.instance_variable_defined?("@metadata")
          current_metadata = target.instance_variable_get("@metadata") || {}
        end

        current_metadata = current_metadata.merge(metadata)
        target.instance_variable_set("@metadata", current_metadata)
      end

      mappings = ActiveSupport::HashWithIndifferentAccess.new(mappings)

      source.each do |key, value|
        variable_name = key
        variable_value = value

        if key != "@metadata"
          serialized = {
            original_attribute: key,
            serialized_attribute: key_mapper ? key_mapper[key] : key,
            original_value: value,
            serialized_value: json_to_variable(value, key, mappings, conventions, parent_path, key_mapper: key_mapper),
            attribute_path: build_path(key, parent_path),
            source: source,
            target: target,
            metadata: current_metadata,
            nested_object_types: nested_object_types
          }

          conventions&.serializers&.each do |serializer|
            serializer.on_unserialized(serialized)
          end

          variable_name = "@#{serialized[:serialized_attribute]}"
          variable_value = serialized[:serialized_value]
        end

        target.instance_variable_set(variable_name, variable_value)
      end

      target
    end

    def self.to_json(source, conventions = nil, parent_path = nil, encode_types: false, metadata: nil)
      json = {}

      if source.is_a?(DocumentInfo)
        metadata ||= source.instance_variable_get("@metadata")
      end

      unless TypeUtilities.document?(source)
        raise "Invalid source passed. Should be a user-defined class instance"
      end

      current_metadata = {}

      if source.instance_variable_defined?("@metadata")
        current_metadata = source.instance_variable_get("@metadata") || {}
      end

      source.instance_variables.each do |variable|
        variable_name = variable.to_s
        variable_value = source.instance_variable_get(variable)
        json_property = variable_name
        json_value = variable_value

        if variable_name != "@metadata"
          json_property = json_property.delete("@")

          serialized = {
            original_attribute: json_property,
            serialized_attribute: json_property,
            original_value: variable_value,
            serialized_value: variable_to_json(variable_value, json_property, conventions, parent_path, metadata: metadata),
            attribute_path: build_path(json_property, parent_path),
            source: source,
            metadata: current_metadata
          }

          conventions&.serializers&.each do |serializer|
            serializer.on_serialized(serialized)
          end

          json_property = serialized[:serialized_attribute]
          json_value = serialized[:serialized_value]
        end

        json[json_property] = json_value
      end

      json
    end

    def self.json_to_variable(json_value, key = nil, mappings = {}, conventions = nil, parent_path = nil, key_mapper: nil)
      mapped_key = key_mapper ? key_mapper[key] : key

      if mappings.key?(mapped_key)
        nested_object_type = mappings[mapped_key]

        if nested_object_type == "date"
          return TypeUtilities.parse_date(json_value)
        end

        if json_value.is_a?(Hash)
          document = json_to_document(json_value, nested_object_type, conventions, build_path(key, parent_path), key_mapper: key_mapper)

          unless document.nil?
            return document
          end
        end

        if json_value.is_a?(Array)
          documents = []

          if json_value.all? do |json_value_item|
               document = json_to_document(json_value_item, nested_object_type, conventions, build_path(key, parent_path), key_mapper: key_mapper)
               was_converted = !document.nil?

               unless document.nil?
                 documents.push(document)
               end

               was_converted
             end
            return documents
          end
        end
      end

      if json_value.is_a?(Array)
        value = []

        json_value.each do |json_array_value|
          value.push(json_to_variable(json_array_value, key, {}, conventions, parent_path))
        end

        return value
      end

      if json_value.is_a?(Hash)
        value = {}

        json_value.each do |json_hash_key, json_hash_value|
          value[json_hash_key.to_s] = json_to_variable(json_hash_value, json_hash_key.to_s, {}, conventions, build_path(key, parent_path))
        end

        return value
      end

      json_value
    end

    def self.json_to_document(json_value, nested_object_type, conventions = nil, parent_path = nil, key_mapper: nil)
      nested_object_metadata = {}

      if json_value.key?("@metadata") && json_value["@metadata"].is_a?(Hash)
        nested_object_metadata = json_value["@metadata"]
      end

      if nested_object_type.is_a?(Class) || nested_object_type.is_a?(String)
        if nested_object_type.is_a?(String)
          nested_object_type = Object.const_get(nested_object_type)
        end

        return from_json(nested_object_type.new, json_value, nested_object_metadata, nil, conventions, parent_path, key_mapper: key_mapper)
      end

      nil
    end

    def self.store_metadata_type(metadata, _parent_path, variable, type)
      if metadata
        metadata["@nested_object_types"] ||= {}
        metadata["@nested_object_types"][variable] = type
      end
    end

    def self.store_object_type(variable)
      metadata = if variable.instance_variable_defined?("@metadata")
                   variable.instance_variable_get("@metadata")
                 else
                   {}
                 end
      metadata["Raven-Ruby-Type"] = variable.class.name
      variable.instance_variable_set("@metadata", metadata)
    end

    def self.variable_to_json(variable_value, variable = nil, conventions = nil, parent_path = nil, metadata: nil)
      if variable != "@metadata" && !!variable_value != variable_value
        if variable_value.is_a?(Date) || variable_value.is_a?(DateTime)
          store_metadata_type(metadata, parent_path, variable, "date")
          return TypeUtilities.stringify_date(variable_value)
        end

        if TypeUtilities.document?(variable_value)
          store_metadata_type(metadata, parent_path, variable, variable_value.class.name)
          store_object_type(variable_value)
          return to_json(variable_value, conventions, build_path(variable, parent_path), metadata: metadata)
        end

        if variable_value.is_a?(Hash)
          json = {}

          variable_value.each do |key, value|
            json[key.to_s] = variable_to_json(value, key.to_s, conventions, build_path(variable, parent_path), metadata: metadata)
          end

          return json
        end

        if variable_value.is_a?(Array)
          json = []

          variable_value.each do |value|
            json.push(variable_to_json(value, variable, conventions, parent_path, metadata: metadata))
          end

          return json
        end
      end

      variable_value
    end

    def self.build_path(attribute, parent_path = nil)
      unless parent_path.nil?
        return "#{parent_path}.#{attribute}"
      end

      attribute
    end

    private_class_method :new, :json_to_variable, :json_to_document, :variable_to_json, :build_path
  end
end
