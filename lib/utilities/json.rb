require "json"
require 'net/http'
require 'database/exceptions'
require 'documents/conventions'
require 'utilities/type_utilities'

class Net::HTTPResponse
  def json(raise_when_invalid = true)
    json = body
    parsed = nil

    if !json.is_a? Hash
      begin
        if json.is_a?(String) && !json.empty?
          parsed = JSON.parse(json)
        end
      rescue
        if raise_when_invalid
          raise RavenDB::ErrorResponseException, 'Not a valid JSON'  
        end  
      end  
    end  

    parsed
  end  
end

module RavenDB
  class JsonSerializer
    def self.from_json(target, source = {}, metadata = {}, nested_object_types = {})
      mappings = {}

      if !TypeUtilities.is_document?(target)
        raise InvalidOperationException, 'Invalid target passed. Should be a user-defined class instance'
      end

      if !source.is_a?(Hash)
        raise InvalidOperationException, 'Invalid source passed. Should be a Hash object'
      end

      if metadata.key?('@nested_object_types') &&
        metadata['@nested_object_types'].is_a?(Hash)
        mappings = mappings.merge(metadata['@nested_object_types'])
      end

      if nested_object_types.is_a?(Hash) && nested_object_types.size
        mappings = mappings.merge(nested_object_types)
      end

      source.each do |key, value|
        variable_name = key

        if "@metadata" != key
          variable_name = "@#{key}"
        end

        target.instance_variable_set(variable_name, json_to_variable(value, key, mappings))
      end

      if metadata.is_a?(Hash) && metadata.size
        current_metadata = target.instance_variable_get('@metadata') || {}

        target.instance_variable_set('@metadata', current_metadata.merge(metadata))
      end

      target
    end

    def self.to_json(source)
      json = {}

      if !TypeUtilities.is_document?(source)
        raise InvalidOperationException, 'Invalid source passed. Should be a user-defined class instance'
      end

      source.instance_variables do |variable|
        variable_name = variable.to_s
        json_property = variable_name
        variable_value = instance_variable_get(variable)

        if '@metadata' != variable_name
          json_property = json_property.gsub('@', '')
        end

        json[json_property] = variable_to_json(variable_value, variable_name)
      end

      json
    end

    protected
    def self.json_to_variable(json_value, key = nil, mappings = {})
      if mappings.key?(key)
        nested_object_type = mappings[key]

        if 'date' == nested_object_type
          return TypeUtilities::parse_date(json_value)
        end

        if json_value.is_a?(Hash)
          nested_object_metadata = {}

          if json_value.key?('@metadata') && json_value['@metadata'].is_a?(Hash)
            nested_object_metadata = json_value['@metadata']
          end

          if nested_object_type.is_a?(Class) || nested_object_type.is_a?(String)
            if nested_object_type.is_a?(String)
              nested_object_type = Object.const_get(nested_object_type)
            end

            return from_json(nested_object_type.new, json_value, nested_object_metadata)
          end
        end
      end

      if json_value.is_a?(Array)
        value = []

        json_value.each do |json_array_value|
          value.push(json_to_variable(json_array_value, key))
        end

        return value
      end

      if json_value.is_a?(Hash)
        value = {}

        json_value.each do |json_hash_key, json_hash_value|
          value[json_hash_key.to_s] = json_to_variable(json_hash_value, json_hash_key.to_s)
        end

        return value
      end

      json_value
    end

    def self.variable_to_json(variable_value, variable = nil)
      if '@metadata' == variable
        return variable_value
      end

      if variable_value.is_a?(Date) || variable_value.is_a?(DateTime)
        return TypeUtilities::stringify_date(variable_value)
      end

      if variable_value.is_a?(RavenDocument)
        return variable_to_json(variable_value)
      end

      if variable_value.is_a?(Hash)
        json = {}

        variable_value.each do |key, value|
          json[key.to_s] = variable_to_json(value, key.to_s)
        end

        return json
      end

      if variable_value.is_a?(Array)
        json = []

        variable_value.each do |value|
          json.push(variable_to_json(value, variable))
        end

        return json
      end

      variable_value
    end
  end
end