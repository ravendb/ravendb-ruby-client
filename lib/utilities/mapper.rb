module RavenDB
  class JsonObjectMapper
    def read_value(response, klass, nested: {}, conventions:)
      result = response.is_a?(Hash) ? response : JSON.parse(response.body)
      target = klass.new
      RavenDB::JsonSerializer.from_json(target, result, {}, nested, conventions, key_mapper: key_mapper)
    end

    def key_mapper
      ->(key) { key.underscore }
    end
  end
end
