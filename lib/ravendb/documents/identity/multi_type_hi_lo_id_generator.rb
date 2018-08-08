module RavenDB
  class MultiTypeHiLoIdGenerator
    def initialize(store, db_name, conventions)
      @store = store
      @db_name = db_name
      @conventions = conventions
      @_id_generators_by_tag = ConcurrentHashMap.new
    end

    def generate_document_id(entity)
      type_tag_name = @conventions.collection_name(entity)
      return nil if type_tag_name.empty?
      tag = @conventions.transform_class_collection_name_to_document_id_prefix[type_tag_name]
      value = @_id_generators_by_tag.compute_if_absent(tag) do
        create_generator_for(tag)
      end
      value.generate_document_id(entity)
    end

    def create_generator_for(tag)
      HiLoIdGenerator.new(tag, @store, @db_name, DocumentConventions.identity_parts_separator)
    end

    def return_unused_range
      @_id_generators_by_tag.values.each(&:return_unused_range)
    end
  end
end
