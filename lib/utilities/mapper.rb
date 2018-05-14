module RavenDB
  class JsonObjectMapper
    def read_value(response, klass)
      result = JSON.parse(response.body)
      conventions = RavenDB::DocumentConventions.new
      target = klass.new
      RavenDB::JsonSerializer.from_json(target, result, {}, {}, conventions, key_mapper: key_mapper)
    end

    def key_mapper
      ->(key) { key.underscore }
    end
  end
end
