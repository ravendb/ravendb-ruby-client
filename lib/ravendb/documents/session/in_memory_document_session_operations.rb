module RavenDB
  class InMemoryDocumentSessionOperations
    attr_reader :included_documents_by_id

    def initialize(conventions:)
      @included_documents_by_id = {}
      @documents_by_id = {}
      @documents_by_entity = {}
      @deleted_entities = []
      @deferred_commands_map = {}
      @mapper = JsonObjectMapper.new # TODO
      @_save_changes_options = BatchOptions.new
      @deferred_commands = Set.new([])
      @generate_entity_id_on_the_client = GenerateEntityIdOnTheClient.new(conventions, ->(object) { generate_id(object) })
    end

    def get_document_id(instance)
      return nil if instance.nil?
      documents_by_entity[instance]&.id
    end

    def loaded_or_deleted?(id)
      document_info = @documents_by_id[id]

      (!document_info.nil? && (!document_info.document.nil? || !document_info.entity.nil?)) ||
        deleted?(id) ||
        @included_documents_by_id[id]
    end

    def deleted?(id)
      @known_missing_ids.include?(id)
    end

    def check_if_id_already_included(ids, includes)
      ids.each do |id|
        next if @known_missing_ids.include?(id)
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
    def convert_to_entity(entity_type:, id: nil, document:)
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
          doc_info.entity = convert_to_entity(entity_type: entity_type, id: id, document: document)
        end
        unless no_tracking
          @included_documents_by_id.delete(id)
          @documents_by_entity[doc_info.entity] = doc_info
        end
        return doc_info.entity
      end
      doc_info = @included_documents_by_id[id]
      unless doc_info.nil?
        if doc_info.entity.nil?
          doc_info.entity = convert_to_entity(entity_type: entity_type, id: id, document: document)
        end
        unless no_tracking
          @included_documents_by_id.delete(id)
          @documents_by_id[id] = doc_info
          @documents_by_entity[doc_info.entity] = doc_info
        end
        return doc_info.entity
      end
      entity = convert_to_entity(entity_type: entity_type, id: id, document: document)
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

    def delete(entity_or_id, expected_change_vector: nil)
      raise ArgumentError, "Entity/ID cannot be null" if entity_or_id.nil?
      if entity_or_id.is_a?(String)
        delete_by_id(entity_or_id, expected_change_vector)
      else
        delete_by_entity(entity_or_id)
      end
    end

    protected

    def delete_by_entity(entity)
      value = @documents_by_entity[entity]
      if value.nil?
        raise "#{entity} is not associated with the session, cannot delete unknown entity instance"
      end
      @deleted_entities << entity
      @included_documents_by_id.delete(value.id)
      @known_missing_ids << value.id
    end

    def convert_to_json(entity_type:, document:)
      metadata = document.instance_variable_get("@metadata")
      json = JsonSerializer.to_json(document, conventions, encode_types: true, metadata: metadata)
      json["entity"]&.delete("id")
      json
    end

    def delete_by_id(id, expected_change_vector)
      change_vector = nil
      document_info = @documents_by_id[id]
      unless document_info.nil?
        new_obj = convert_to_json(entity_type: document_info.entity.class, document: document_info.entity)
        if !document_info.entity.nil? && entity_changed(new_obj, document_info, nil)
          raise "Can't delete changed entity using identifier. Use delete(entity) instead."
        end
        unless document_info.entity.nil?
          @documents_by_entity.delete(document_info.entity)
        end
        @documents_by_id.delete(id)
        change_vector = document_info.change_vector
      end
      @known_missing_ids.add(id)
      change_vector = (use_optimistic_concurrency? ? change_vector : nil)
      defer(DeleteCommandData.new(id, [expected_change_vector, change_vector].compact.first))
    end

    def entity_changed(new_obj, document_info, changes)
      JsonOperation.entity_changed(new_obj, document_info, changes)
    end

    def use_optimistic_concurrency?
      true # TODO
    end

    def defer(*commands)
      @deferred_commands += commands
      commands.each do |command|
        defer_internal(command)
      end
    end

    def defer_internal(command)
      @deferred_commands_map[IdTypeAndName.new(command.id, command.type, command.name)] = command
      @deferred_commands_map[IdTypeAndName.new(command.id, :client_any_command, nil)] = command
      if command.type != :attachment_put && command.type != :attachment_delete
        @deferred_commands_map[IdTypeAndName.new(command.id, :client_not_attachment, nil)] = command
      end
    end

    def try_get_id_from_instance(entity, string_reference)
      id = conventions.get_id_from_document(entity)
      string_reference.value = id if id
      !!id
    end

    public

    def try_set_identity(entity, id)
      conventions.set_id_on_document(entity, id)
    end

    def store(entity, id: nil, change_vector: nil)
      if id
        concurrency_check_mode = change_vector ? :forced : :disabled
      else
        string_reference = Reference.new
        has_id = try_get_id_from_instance(entity, string_reference)
        id = string_reference.value if has_id
        concurrency_check_mode = has_id ? :auto : :forced
      end
      store_internal(entity, change_vector, id, concurrency_check_mode)
    end

    protected

    # TODO: move to constants
    COLLECTION = "@collection".freeze
    PROJECTION = "@projection".freeze
    KEY = "@metadata".freeze
    ID = "@id".freeze
    CONFLICT = "@conflict".freeze
    ID_PROPERTY = "Id".freeze
    FLAGS = "@flags".freeze
    ATTACHMENTS = "@attachments".freeze
    INDEX_SCORE = "@index-score".freeze
    LAST_MODIFIED = "@last-modified".freeze
    RAVEN_JAVA_TYPE = "Raven-Java-Type".freeze
    RAVEN_RUBY_TYPE = "Raven-Ruby-Type".freeze
    CHANGE_VECTOR = "@change-vector".freeze
    EXPIRES = "@expires".freeze

    def store_internal(entity, change_vector, id, force_concurrency_check)
      raise ArgumentError, "Entity cannot be null" if entity.nil?
      value = @documents_by_entity[entity]
      unless value.nil?
        value.change_vector ||= change_vector
        value.concurrency_check_mode = force_concurrency_check
        return
      end
      if id.nil?
        id = @generate_entity_id_on_the_client.generate_document_key_for_storage(entity)
      else
        try_set_identity(entity, id)
      end
      if @deferred_commands_map.key?(IdTypeAndName.new(id, :client_any_command, nil))
        raise "Can't store document, there is a deferred command registered for this document in the session. Document id: #{id}"
      end
      if @deleted_entities.include?(entity)
        raise "Can't store object, it was already deleted in this session. Document id: #{id}"
      end
      assert_no_non_unique_instance(entity, id)
      metadata = entity.instance_variable_get("@metadata") || {}
      metadata[COLLECTION] = @request_executor.conventions.collection_name(entity)
      metadata[RAVEN_RUBY_TYPE] = @request_executor.conventions.ruby_class_name(entity.class)
      @known_missing_ids.delete(id) if id
      store_entity_in_unit_of_work(id, entity, change_vector, metadata.compact, force_concurrency_check)
    end

    def store_entity_in_unit_of_work(id, entity, change_vector, metadata, force_concurrency_check)
      @deleted_entities.delete(entity)
      @known_missing_ids.delete(id) if id
      document_info = DocumentInfo.new
      document_info.id = id
      document_info.metadata = metadata
      document_info.change_vector = change_vector
      document_info.concurrency_check_mode = force_concurrency_check
      document_info.entity = entity
      document_info.new_document = true
      document_info.document = nil
      @documents_by_entity[entity] = document_info
      @documents_by_id[id] = document_info if id
    end

    public

    attr_reader :deferred_commands

    attr_reader :deferred_commands_map

    attr_reader :_save_changes_options

    def prepare_for_save_changes
      result = SaveChangesData.new(self)
      @deferred_commands.clear
      @deferred_commands_map.clear
      prepare_for_entities_deletion(result, nil)
      prepare_for_entities_puts(result)
      unless @deferred_commands.empty?
        result.deferred_commands.add_all(@deferred_commands)
        @deferred_commands_map.entry_set.each do |item|
          result.deferred_commands_map.put(item.key, item.value)
        end
        @deferred_commands.clear
        @deferred_commands_map.clear
      end
      result
    end

    def self.update_metadata_modifications(document_info)
      # TODO
      dirty = false
      unless document_info.metadata_instance.nil?
        dirty = true if document_info.metadata_instance.dirty?
        document_info.metadata_instance.key_set.each do |prop|
          prop_value = document_info.metadata_instance.get(prop)
          if prop_value.nil? || (prop_value.is_a?(MetadataAsDictionary) && prop_value.dirty?)
            dirty = true
          end
          document_info.metadata.set(prop, mapper.convert_value(prop_value, JsonNode))
        end
      end
      dirty
    end

    protected

    def prepare_for_entities_deletion(result, changes)
      # TODO
      @deleted_entities.each do |deleted_entity|
        document_info = @documents_by_entity[deleted_entity]
        next if document_info.nil?
        if !changes.nil?
          doc_changes = ArrayList.new
          change = DocumentsChanges.new
          change.field_new_value = ""
          change.field_old_value = ""
          change.change = documents_changes.change_type.document_deleted
          doc_changes.add(change)
          changes.put(document_info.id, doc_changes)
        else
          command = result.deferred_commands_map[IdTypeAndName.new(document_info.id, :client_any_command, nil)]
          unless command.nil?
            throw_invalid_deleted_document_with_deferred_command(command)
          end
          change_vector = nil
          document_info = @documents_by_id[document_info.id]
          unless document_info.nil?
            change_vector = document_info.change_vector
            unless document_info.entity.nil?
              @documents_by_entity.delete(document_info.entity)
              result.entities << document_info.entity
            end
            @documents_by_id.delete(document_info.id)
          end
          change_vector = nil unless use_optimistic_concurrency?
          # before_delete_event_args = BeforeDeleteEventArgs.new(self, document_info.id, document_info.entity)
          # event_helper.invoke(@on_before_delete, self, before_delete_event_args) # TODO
          result.session_commands << DeleteCommandData.new(document_info.id, change_vector)
        end
        @deleted_entities.clear if changes.nil?
      end
    end

    def prepare_for_entities_puts(result)
      @documents_by_entity.each do |key, value|
        next if value.ignore_changes?
        dirty_metadata = InMemoryDocumentSessionOperations.update_metadata_modifications(value)
        document = convert_entity_to_json(key, value) # TODO
        next if !entity_changed(document, value, nil) && !dirty_metadata
        command = result.deferred_commands_map[IdTypeAndName.new(value.id, :client_not_attachment, nil)]
        unless command.nil?
          throw_invalid_modified_document_with_deferred_command(command)
        end
        on_before_store = @on_before_store
        if !on_before_store.nil? && !on_before_store.empty?
          # TODO
          before_store_event_args = BeforeStoreEventArgs.new(self, value.id, key)
          event_helper.invoke(on_before_store, self, before_store_event_args)
          if before_store_event_args.metadata_accessed?
            update_metadata_modifications(value)
          end
          if before_store_event_args.metadata_accessed? || entity_changed(document, value, nil)
            document = @entity_to_json.convert_entity_to_json(key, value)
          end
        end
        value.new_document = false
        result.entities << key
        @documents_by_id.delete(value.id) unless value.id.nil?
        value.document = document
        change_vector = if use_optimistic_concurrency?
                          if value.concurrency_check_mode != :disabled
                            value.change_vector || ""
                          end
                        elsif value.concurrency_check_mode == :forced
                          value.change_vector
                        end
        metadata = document.slice("@metadata")
        metadata["@id"] = value.id # TODO
        metadata["@nested_object_types"] = nil # TODO
        document = document["entity"].merge(metadata)
        result.session_commands << PutCommandDataWithJson.new(value.id, change_vector, document)
      end
    end

    def convert_entity_to_json(_key, value)
      convert_to_json(entity_type: nil, document: value)
    end
  end
end
