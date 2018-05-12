module RavenDB
  class PutAttachmentCommand < AttachmentCommand
    def initialize(document_id, name, stream, content_type = nil, change_vector = nil)
      super(document_id, name, change_vector)

      @_stream = stream
      @_content_type = content_type

      raise ArgumentError, "Attachment can't be empty" if
          stream.nil? || stream.empty?
    end

    def create_request(server_node)
      super(server_node)

      @headers["Content-Type"] = "application/octet-stream"
      @method = Net::HTTP::Put::METHOD

      unless @_change_vector.nil?
        @headers["If-Match"] = "\"#{@_change_vector}\""
      end

      return if @_content_type.blank?

      @headers["Content-Type"] = @_content_type
      @params["contentType"] = @_content_type
    end

    def to_request_options
      request = super()

      request.body = @_stream
      request
    end
  end
end
