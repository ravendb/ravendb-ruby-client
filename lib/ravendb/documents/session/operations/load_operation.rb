module RavenDB
  class LoadOperation
    def initialize(session)
      @session = session
      @ids = nil
      @ids_to_check_on_server = []
      @includes = nil
    end

    def by_id(id)
      return self if id.nil?

      if @ids.nil?
        @ids = [id]
      else
        @ids << id
      end

      if @session.loaded_or_deleted?(id)
        return self
      end

      @ids_to_check_on_server << id
      self
    end

    def by_ids(ids)
      ids.compact.each { |id| by_id(id) }
      self
    end

    def with_includes(includes)
      @includes = includes
      self
    end

    def create_request
      if @ids_to_check_on_server.empty?
        return nil
      end

      if @session.check_if_id_already_included(@ids, @includes)
        return nil
      end

      @session.increment_requests_count!

      RavenDB.logger.info { "Requesting the following ids #{@ids_to_check_on_server.join(', ')} from #{@session.store_identifier}" }

      GetDocumentsCommand.new(ids: @ids_to_check_on_server, includes: @includes, metadata_only: false)
    end

    def get_document(klass, id)
      if id.nil?
        return nil
      end

      if @session.deleted?(id)
        return nil
      end

      doc = @session.documents_by_id[id]
      unless doc.nil?
        return @session.track_entity(klass: klass, document_found: doc)
      end

      doc = @session.included_documents_by_id[id]
      unless doc.nil?
        return @session.track_entity(klass: klass, document_found: doc)
      end

      nil
    end

    def get_documents(klass)
      @ids.map { |id| [id, get_document(klass, id)] }.to_h
    end

    def result=(result)
      return if result.nil?
      @session.register_includes(result["Includes"])
      result["Results"].compact.each do |document|
        new_document_info = DocumentInfo.new(document)
        @session.documents_by_id[new_document_info.id] = new_document_info
      end
      @session.register_missing_includes(result["Results"], result["Includes"], @_includes)
    end
  end
end
