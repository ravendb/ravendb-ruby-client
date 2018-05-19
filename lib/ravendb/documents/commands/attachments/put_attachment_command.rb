module RavenDB
  class PutAttachmentCommand < AttachmentCommand
    def initialize(document_id, name, stream, content_type = nil, change_vector = nil)
      super(document_id, name, change_vector)

      @_stream = stream
      @_content_type = content_type

      raise ArgumentError, "Attachment can't be empty" if stream.nil? || stream.empty?
    end

    def create_request(server_node)
      request = super(server_node)

      request["Content-Type"] = "application/octet-stream"

      unless @_change_vector.nil?
        request["If-Match"] = "\"#{@_change_vector}\""
      end

      unless @_content_type.blank?
        request["Content-Type"] = @_content_type
      end

      request.body = payload
      request
    end

    def params
      params = super
      unless @_content_type.blank?
        params["contentType"] = @_content_type
      end
      params
    end

    def payload
      @_stream
    end

    def http_method
      Net::HTTP::Put
    end
  end
end
