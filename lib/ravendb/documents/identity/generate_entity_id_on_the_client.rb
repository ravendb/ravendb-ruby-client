module RavenDB
  class GenerateEntityIdOnTheClient
    def initialize(conventions, generate_id)
      @_conventions = conventions
      @_generate_id = generate_id
    end

    def identity_property(entity_type)
      @_conventions.identity_property(entity_type)
    end

    def try_get_id_from_instance(entity, id_holder)
      raise ArgumentError, "Entity cannot be null" if entity.nil?
      identity_property = identity_property(entity.class)
      unless identity_property.nil?
        value = entity.send(identity_property)
        if value.is_a?(String)
          id_holder.value = value
          return true
        end
      end
      id_holder.value = nil
      false
    end

    def or_generate_document_id(entity)
      id_holder = Reference.new
      try_get_id_from_instance(entity, id_holder)
      id = id_holder.value
      id = @_generate_id[entity] if id.nil?
      if !id.nil? && id.start_with?("/")
        raise "Cannot use value '#{id}' as a document id because it begins with a '/'"
      end
      id
    end

    def generate_document_key_for_storage(entity)
      id = or_generate_document_id(entity)
      try_set_identity(entity, id)
      id
    end

    def try_set_identity(entity, id)
      entity_type = entity.class
      identity_property = @_conventions.identity_property(entity_type)
      return if identity_property.nil?
      set_property_or_field(entity, identity_property, id)
    end

    def set_property_or_field(entity, field, id)
      entity.send("#{field}=", id)
    end
  end
end
