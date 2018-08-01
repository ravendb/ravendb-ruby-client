require "database/exceptions"
require "documents/conventions"
require "constants/documents"
require "database/commands"
require "documents/document_query"
require "utilities/type_utilities"
require "utilities/observable"

module RavenDB
  class DocumentSession < InMemoryDocumentSessionOperations
    include Observable

    attr_reader :number_of_requests_in_session
    attr_reader :documents_by_id
    attr_reader :documents_by_entity

    def initialize(db_name, document_store, id, request_executor, conventions:)
      super(conventions: conventions)

      @advanced = nil
      @database = db_name
      @document_store = document_store
      @session_id = id
      @request_executor = request_executor
      @included_raw_entities_by_id = {}
      @deleted_documents = Set.new([])
      @raw_entities_and_metadata = {}
      @known_missing_ids = Set.new([])
      @attached_queries = {}
      @number_of_requests_in_session = 0

      on(RavenServerEvent::EVENT_QUERY_INITIALIZED) do |query|
        attach_query(query)
      end
    end

    def conventions
      @document_store.conventions
    end

    def advanced
      self
    end

    def query(options = nil)
      document_query = DocumentQuery.create(self, @request_executor, options)

      emit(RavenServerEvent::EVENT_QUERY_INITIALIZED, document_query)

      document_query
    end

    protected

    def attach_query(query)
      if @attached_queries.key?(query)
        raise "Query is already attached to session"
      end

      query.on(RavenServerEvent::EVENT_DOCUMENTS_QUERIED) do
        increment_requests_count!
      end

      query.on(RavenServerEvent::EVENT_DOCUMENT_FETCHED) do |conversion_result|
        on_document_fetched(conversion_result)
      end

      query.on(RavenServerEvent::EVENT_INCLUDES_FETCHED) do |includes|
        on_includes_fetched(includes)
      end

      @attached_queries[query] = true
    end

    public

    def increment_requests_count!
      max_requests = DocumentConventions.max_number_of_request_per_session

      @number_of_requests_in_session += 1

      unless @number_of_requests_in_session <= max_requests
        raise "The maximum number of requests (#{max_requests}) allowed for this session has been reached. Raven limits the number "\
  "of remote calls that a session is allowed to make as an early warning system. Sessions are expected to "\
  "be short lived, and Raven provides facilities like batch saves (call save_changes only once) "\
  "You can increase the limit by setting RavenDB::DocumentConventions."\
  "max_number_of_request_per_session, but it is advisable "\
  "that you'll look into reducing the number of remote calls first, "\
  "since that will speed up your application significantly and result in a"\
  "more responsive application."
      end
    end

    protected

    def fetch_documents(ids, includes = nil, nested_object_types = {}, document_type: nil)
      response_results = []
      response_includes = []
      increment_requests_count!

      command = GetDocumentCommand.new(ids, includes)
      @request_executor.execute(command)
      response = command.result

      if response
        response_results = conventions.try_fetch_results(response)
        response_includes = conventions.try_fetch_includes(response)
      end

      response_results.map.with_index do |result, index|
        unless result
          @known_missing_ids.add(ids[index])
          return nil
        end

        make_document(result, document_type, nested_object_types)
      end

      return if response_includes.empty?

      on_includes_fetched(response_includes)
    end

    def check_document_and_metadata_before_store(document = nil)
      unless TypeUtilities.document?(document)
        raise "Invalid argument passed. Should be an document"
      end

      unless @raw_entities_and_metadata.key?(document)
        document.instance_variable_set("@metadata", conventions.build_default_metadata(document))
      end

      document
    end

    def check_association_and_change_vectore_before_store(document, id = nil, change_vector = nil)
      is_new = !@raw_entities_and_metadata.key?(document)

      unless is_new
        document_id = id
        info = @raw_entities_and_metadata[document]
        metadata = document.instance_variable_get("@metadata")
        check_mode = ConcurrencyCheckMode::FORCED

        if document_id.nil?
          document_id = conventions.get_id_from_document(document)
        end

        if change_vector.nil?
          check_mode = ConcurrencyCheckMode::DISABLED
        else
          info[:change_vector] = metadata["@change-vector"] = change_vector

          unless document_id.nil?
            check_mode = ConcurrencyCheckMode::AUTO
          end
        end

        info[:concurrency_check_mode] = check_mode
        @raw_entities_and_metadata[document] = info
      end

      {document: document, is_new: is_new}
    end

    def prepare_document_id_before_store(document, id = nil)
      store = @document_store
      document_id = id

      if document_id.nil?
        document_id = conventions.get_id_from_document(document)
      end

      unless document_id.nil?
        conventions.set_id_on_document(document, document_id)
      end

      if !document_id.nil? && !document_id.end_with?("/") && @documents_by_id.key?(document_id)
        unless @documents_by_id[document_id].eql?(document)
          raise NonUniqueObjectException, "Attempted to associate a different object with id #{document_id}"
        end
      end

      if document_id.nil? || document_id.end_with?("/")
        document_type = conventions.get_type_from_document(document)
        document_id = store.generate_id(conventions.get_collection_name(document_type), @database)
        conventions.set_id_on_document(document, document_id)
      end

      document
    end

    def prepare_update_commands(changes)
      @raw_entities_and_metadata.each do |document, info|
        unless document_changed?(document)
          return nil
        end

        id = info[:id]
        change_vector = nil
        raw_entity = conventions.convert_to_raw_entity(document)

        if (DocumentConventions.default_use_optimistic_concurrency &&
          (ConcurrencyCheckMode::DISABLED != info[:concurrency_check_mode])) ||
           (ConcurrencyCheckMode::FORCED == info[:concurrency_check_mode])
          change_vector = info[:change_vector] ||
                          info[:metadata]["@change-vector"] ||
                          conventions.empty_change_vector
        end

        @documents_by_id.delete(id)
        changes.add_document(document)
        changes.add_command(PutCommandData.new(id, raw_entity.deep_dup, change_vector))
      end
    end

    def prepare_delete_commands(changes)
      @deleted_documents.each do |document|
        change_vector = nil
        existing_document = document
        document_id = conventions.get_id_from_document(document)

        if @raw_entities_and_metadata.key?(document)
          info = @raw_entities_and_metadata[document]

          if @documents_by_id.key?(info[:id])
            document_id = info[:id]
            existing_document = @documents_by_id[document_id]
            @documents_by_id.delete(document_id)
          end

          if info.key?(:expected_change_vector)
            change_vector = info[:expected_change_vector]
          elsif DocumentConventions.default_use_optimistic_concurrency
            change_vector = info[:change_vector] || info[:metadata]["@change-vector"]
          end

          @raw_entities_and_metadata.delete(document)
        end

        changes.add_document(existing_document)
        changes.add_command(DeleteCommandData.new(document_id, change_vector))
      end
    end

    def process_batch_command_results(results, changes)
      ((changes.deferred_commands_count)..(results.size - 1)).each do |index|
        command_result = results[index]

        next unless Net::HTTP::Put::METHOD.capitalize == command_result["Type"]
        document = changes.get_document(index - changes.deferred_commands_count)

        next unless @raw_entities_and_metadata.key?(document)
        metadata = command_result.except("Type")
        info = @raw_entities_and_metadata[document]

        info = info.merge(
          change_vector: command_result["@change-vector"],
          metadata: metadata,
          original_value: conventions.convert_to_raw_entity(document).deep_dup,
          original_metadata: metadata.deep_dup
        )

        @documents_by_id[command_result["@id"]] = document
        @raw_entities_and_metadata[document] = info
      end
    end

    def document_changed?(document)
      unless @raw_entities_and_metadata.key?(document)
        return false
      end

      info = @raw_entities_and_metadata[document]
      (info[:original_metadata] != info[:metadata]) ||
        (info[:original_value] != conventions.convert_to_raw_entity(document))
    end

    def make_document(command_result, document_type = nil, nested_object_types = nil)
      conversion_result = conventions.convert_to_document(command_result, document_type, nested_object_types)

      on_document_fetched(conversion_result)
      conversion_result[:document]
    end

    def on_includes_fetched(includes)
      return unless includes.is_a?(Array) && !includes.empty?

      includes.each do |include|
        document_id = include["@metadata"]["@id"]

        unless @included_raw_entities_by_id.key?(document_id)
          @included_raw_entities_by_id[document_id] = include
        end
      end
    end

    def on_document_fetched(conversion_result = nil)
      if conversion_result.nil?
        return nil
      end

      document = conversion_result[:document]
      document_id = conventions.get_id_from_document(document) ||
                    conversion_result[:original_metadata]["@id"] || conversion_result[:metadata]["@id"]

      unless document_id
        return nil
      end

      @known_missing_ids.delete(document_id)

      if @documents_by_id.key?(document_id)
        return nil
      end

      original_value_source = conversion_result[:raw_entity]

      original_value_source ||= conventions.convert_to_raw_entity(document)

      @documents_by_id[document_id] = document
      @raw_entities_and_metadata[document] = {
        original_value: original_value_source.deep_dup,
        original_metadata: conversion_result[:original_metadata],
        metadata: conversion_result[:metadata],
        change_vector: conversion_result[:metadata]["@change-vector"],
        id: document_id,
        concurrency_check_mode: ConcurrencyCheckMode::AUTO,
        document_type: conversion_result[:document_type]
      }
    end

    public

    def raw_query(query, params = {}, options = nil)
      document_query = RawDocumentQuery.create(self, @request_executor, options)
      document_query.raw_query(query)

      if params.is_a?(Hash) && !params.empty?
        params.each { |param, value| document_query.add_parameter(param, value) }
      end

      emit(RavenServerEvent::EVENT_QUERY_INITIALIZED, document_query)

      document_query
    end

    def get_change_vector_for(instance)
      raise ArgumentError, "instance cannot be null" if instance.nil?

      document_info = get_document_info(instance)
      change_vector = document_info.change_vector
      change_vector&.to_s || ""
    end

    def get_document_info(instance)
      document_info = documents_by_entity[instance]

      return document_info unless document_info.nil?

      id = instance.id

      assert_no_non_unique_instance(instance, id)

      raise ArgumentError, "Document #{id} doesn't exist in the session"
    end

    def assert_no_non_unique_instance(entity, id)
      return if id.empty? || id[-1] == "|" || id[-1] == "/"

      info = documents_by_id[id]

      return if info.nil? || info.entity == entity

      raise "Attempted to associate a different object with id '#{id}'."
    end

    def document_query(klass, index_klass: nil, index_name: nil, collection_name: nil, is_map_reduce: false)
      if index_name && collection_name
        raise ArgumentError, "Parameters index_name and collection_name are mutually exclusive." \
          "Please specify only one of them."
      end

      if index_klass
        index = index_klass.new
        index_name = index.index_name
      end

      if !index_name && !collection_name
        collection_name = conventions.get_collection_name(klass)
      end

      DocumentQuery.new(session: self,
                        request_executor: @request_executor,
                        document_type_or_class: klass,
                        index_name: index_name,
                        collection: collection_name)
    end

    def include(path)
      MultiLoaderWithInclude.new(self).include(path)
    end

    def load_internal(klass:, ids:, includes:)
      load_operation = LoadOperation.new(self)
      load_operation.by_ids(ids)
      load_operation.with_includes(includes)
      command = load_operation.create_request
      unless command.nil?
        @request_executor.execute(command, session_info: @session_info)
        load_operation.result = command.result
      end
      load_operation.get_documents(klass)
    end

    def number_of_requests
      number_of_requests_in_session
    end

    # TODO
    def load_new(klass, ids)
      single_doc = !ids.is_a?(Array)
      ids = [ids] if single_doc
      ret = load_internal(klass: klass, ids: ids, includes: nil)
      ret = ret.values.first if single_doc
      ret
    end

    def save_changes
      save_change_operation = BatchOperation.new(self)
      command = save_change_operation.create_request
      return if command.nil?
      @request_executor.execute(command, session_info: @session_info)
      save_change_operation.result = command.result
      save_change_operation
    end

    def database_name
      @database
    end

    def generate_id(entity)
      conventions.generate_document_id(database_name, entity)
    end
  end
end
