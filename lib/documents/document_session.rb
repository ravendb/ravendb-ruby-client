require 'deep_clone'
require 'database/exceptions'
require 'documents/conventions'
require 'constants/documents'

module RavenDB
  class DocumentSession
    def initialize(db_name, document_store, id, request_executor)
      raise InvalidOperationException,
        'Invalid document store provided, Should be an DocumentStore class instance' unless
        document_store.class.name == 'DocumentStore'

      raise InvalidOperationException,
        'Invalid request executor provided, Should be an RequestExecutor class instance' unless
        request_executor.class.name == 'RequestExecutor'

      @database = db_name
      @document_store = document_store
      @session_id = id
      @request_executor = request_executor
      @documents_by_id = {}
      @included_raw_entities_by_id = {}
      @deleted_documents = Set.new([])
      @raw_entities_and_metadata = {}
      @known_missing_ids = Set.new([])
      @defer_commands = Set.new([])
      @attached_queries = {}
      @number_of_requests_in_session = 0
    end

    def conventions
      @document_store.conventions
    end

    def advanced
      @advanced ||= AdvancedSessionOperations.new(self, @request_executor)
    end

    protected
    def increment_requests_count
      max_requests = DocumentConventions::MaxNumberOfRequestPerSession

      @number_of_requests_in_session = @number_of_requests_in_session + 1

      raise InvalidOperationException,
          "The maximum number of requests (#{max_requests}) allowed for this session has been reached. Raven limits the number "\
"of remote calls that a session is allowed to make as an early warning system. Sessions are expected to "\
"be short lived, and Raven provides facilities like batch saves (call saveChanges() only once) "\
"You can increase the limit by setting DocumentConvention."\
"MaxNumberOfRequestsPerSession or MaxNumberOfRequestsPerSession, but it is advisable "\
"that you'll look into reducing the number of remote calls first, "\
"since that will speed up your application significantly and result in a"\
"more responsive application." unless @number_of_requests_in_session <= max_requests
    end

    def is_document_changes(document)
      if !@raw_entities_and_metadata.key?(document)
        return false
      end

      (info[:original_metadata] != info[:metadata]) ||
          (info[:original_value] != conventions.convert_to_raw_entity(document))
    end

    def make_document(command_result, document_type = nil, nested_object_types = nil)
      conversion_result = conventions.convert_to_document(command_result, document_type, nested_object_types)

      on_document_fetched(conversion_result)
      conversion_result[:document]
    end

    def on_includes_fetched(includes)
      if includes.is_a?(Array) && !includes.empty?
        includes.each do |include|
          document_id = include['@metadata']['@id']

          if !@included_raw_entities_by_id.key(document_id)
            @included_raw_entities_by_id[document_id] = include
          end
        end
      end
    end

    def on_document_fetched(conversion_result = nil)
      if conversion_result.nil?
        return nil
      end

      document = conversion_result[:document]
      document_id = conventions.get_id_from_document(document) ||
        conversion_result[:original_metadata]['@id'] || conversion_result[:metadata]['@id']

      if !document_id
        return nil
      end

      @known_missing_ids.delete(document_id)

      if @documents_by_id.key?(document_id)
        return nil
      end

      original_value_source = conversion_result[:raw_entity]

      if !original_value_source
        original_value_source = conventions.convert_to_raw_entity(document)
      end

      @documents_by_id[document_id] = document
      @raw_entities_and_metadata[document] = {
        :original_value => DeepClone.clone(original_value_source),
        :original_metadata => conversion_result[:original_metadata],
        :metadata => conversion_result[:metadata],
        :change_vector => conversion_result[:metadata]['change-vector'] || nil,
        :id => document_id,
        :concurrency_check_mode => ConcurrencyCheckMode::Auto,
        :document_type => conversion_result[:document_type]
      }
    end
  end

  class AdvancedSessionOperations
    def initialize(document_session, request_executor)
      @session = document_session
      @request_executor = request_executor
    end
  end
end