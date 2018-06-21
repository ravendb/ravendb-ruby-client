module RavenDB
  class InMemoryDocumentSessionOperations
    attr_reader :included_documents_by_id

    def initialize
      @_known_missing_ids = {}
      @included_documents_by_id = {}
      @documents_by_id = {}
    end

    def get_document_id(instance)
      return nil if instance.nil?
      documents_by_entity[instance]&.[](:id)
    end

    def loaded_or_deleted?(id)
      document_info = @documents_by_id[id]

      (!document_info.nil? && (!document_info.document.nil? || !document_info.entity.nil?)) ||
        deleted?(id) ||
        @included_documents_by_id[id]
    end

    def deleted?(id)
      @_known_missing_ids[id]
    end

    def check_if_id_already_included(ids, includes)
      ids.each do |id|
        next if @_known_missing_ids[id]
        document_info = @documents_by_id[id]
        if document_info.nil?
          document_info = @included_documents_by_id[id]
          return false if document_info.nil?
        end
        return false if document_info.entity.nil?
        next if includes.nil?
        includes.each do |_include|
          has_all = [true]
          # does nothing in java
          # IncludesUtil.include(document_info.document, include) do  |s|
          #   has_all[0] &= loaded?(s)
          # end
          return false unless has_all[0]
        end
      end
      true
    end

    def store_identifier
      "#{@document_store.identifier};#{@database}"
    end

    def register_includes(includes)
      return if includes.nil?
      includes.compact.each do |_field_name, field_value|
        json = field_value
        new_document_info = DocumentInfo.new(json)
        # TODO: next if JsonExtensions.try_get_conflict(new_document_info.metadata)
        @included_documents_by_id[new_document_info.id] = new_document_info
      end
    end

    def register_missing_includes(results, _includes, include_paths)
      return if include_paths.nil? || include_paths.empty?
      results.each do |_result|
        include_paths.each do |include|
          next if include == "id()" # TODO: constant
          # TODO, does nothing in java
        end
      end
    end

    # TODO
    def convert_to_entity(entity_type, _id, document)
      conventions.convert_to_document(document, entity_type, {})[:document]
    end

    def track_entity(klass: nil, document_found: nil, entity_type: nil, id: nil, document: nil, metadata: nil, no_tracking: false)
      if klass && document_found
        entity_type = klass
        id = document_found.id
        document = document_found.document
        metadata = document_found.metadata
      end
      if id.empty?
        return # TODO: deserialize_from_transformer(entity_type, nil, document)
      end
      doc_info = @documents_by_id[id]
      unless doc_info.nil?
        if doc_info.entity.nil?
          doc_info.entity = convert_to_entity(entity_type, id, document)
        end
        unless no_tracking
          @included_documents_by_id.delete(id)
          documents_by_entity[doc_info.entity] = doc_info
        end
        return doc_info.entity
      end
      doc_info = @included_documents_by_id[id]
      unless doc_info.nil?
        if doc_info.entity.nil?
          doc_info.entity = convert_to_entity(entity_type, id, document)
        end
        unless no_tracking
          @included_documents_by_id.delete(id)
          @documents_by_id[id] = doc_info
          documents_by_entity[doc_info.entity] = doc_info
        end
        return doc_info.entity
      end
      entity = @entity_to_json.convert_to_entity(entity_type, id, document)
      change_vector = metadata.get(constants.documents.metadata.change_vector).as_text
      if change_vector.nil?
        raise "Document #{id} must have Change Vector"
      end
      unless no_tracking
        new_document_info = DocumentInfo.new
        new_document_info.id = id
        new_document_info.document = document
        new_document_info.metadata = metadata
        new_document_info.entity = entity
        new_document_info.change_vector = change_vector
        @documents_by_id[id] = new_document_info
        @documents_by_entity[entity] = new_document_info
      end
      entity
    end
  end
end
