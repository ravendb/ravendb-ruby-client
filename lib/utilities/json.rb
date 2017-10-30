require "json"
require 'net/http'
require 'database/exceptions'
require 'documents/conventions'
require 'utilities/date'

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

      if !source.is_a?(RavenDocument)
        raise InvalidOperationException, 'Invalid source passed. Should be a user-defined class instance'
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
        target.instance_variable_set("@#{key}", json_to_variable(value, key, mappings))
      end

      if metadata.is_a?(Hash) && metadata.size
        target.metadata = target.metadata .merge(metadata)
      end

      target
    end

    def self.to_json(source)
      json = {}

      if !source.is_a?(RavenDocument)
        raise InvalidOperationException, 'Invalid source passed. Should be a user-defined class instance'
      end

      source.instance_variables do |variable|
        json_property = variable.to_s.gsub('@', '')
        variable_value = instance_variable_get(variable)

        json[json_property] = variable_to_json(variable_value, variable.to_s)
      end

      json
    end
  end

  protected
  def self.json_to_variable(json_value, key = nil, mappings = {})
    if mappings.key?(key)
      nested_object_type = mappings[key]

      if 'date' == nested_object_type
        return DateUtil::parse(json_value)
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

      json_value.each do |value|
        value.push(json_to_variable(value, key))
      end

      return value
    end

    if json_value.is_a?(Hash)
      value = {}

      json_value.each do |key, value|
        value[key.to_s] = json_to_variable(value, key.to_s)
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
      return DateUtil::stringify(variable_value)
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