module RavenDB
  class BatchOperation
    def initialize(session)
      @_session = session
    end

    def create_request
      result = @_session.prepare_for_save_changes
      @_session_commands_count = result.session_commands.size
      result.session_commands.concat(result.deferred_commands.to_a)
      return nil if result.session_commands.empty?
      @_session.increment_requests_count!
      @_entities = result.entities
      NewBatchCommand.new(@_session.conventions, result.session_commands, result.options)
    end

    # TODO: constants
    CHANGE_VECTOR = "@change-vector".freeze
    ID = "@id".freeze
    KEY = "@metadata".freeze

    def result=(result)
      result_results = result["Results"]
      if result_results.nil?
        throw_on_null_results
        return
      end

      @_session_commands_count.times do |i|
        batch_result = result_results[i]
        raise "IllegalArgumentException" if batch_result.nil?
        type = batch_result["Type"]
        next unless type == "PUT"
        entity = @_entities[i]
        document_info = @_session.documents_by_entity[entity]
        next if document_info.nil?
        change_vector = batch_result[CHANGE_VECTOR]
        if change_vector.nil?
          raise  "PUT response is invalid. @change-vector is missing on #{document_info.id}"
        end
        id = batch_result[ID]
        if id.nil?
          raise  "PUT response is invalid. @id is missing on #{document_info.id}"
        end
        batch_result.each do |property_name, property_value|
          unless property_name == "Type"
            document_info.metadata[property_name] = property_value
          end
        end
        document_info.id = id
        document_info.change_vector = change_vector
        document_info.document[KEY] = document_info.metadata
        document_info.metadata_instance = nil
        @_session.documents_by_id[id] = document_info
        @_session.try_set_identity(entity, id)
        # TODO
        # after_save_changes_event_args = AfterSaveChangesEventArgs.new(@_session, document_info.id, document_info.entity)
        # @_session.on_after_save_changes_invoke(after_save_changes_event_args)
      end
    end

    def self.throw_on_null_results
      raise "Received empty response from the server. This is not supposed to happen and is likely a bug."
    end
  end
end
