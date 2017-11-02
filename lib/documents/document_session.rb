require 'database/exceptions'

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
    end
  end
end