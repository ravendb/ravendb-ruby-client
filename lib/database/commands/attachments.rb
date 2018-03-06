module RavenDB
  class AttachmentCommand < RavenCommand
    def initialize(document_id, name, change_vector = nil)
      super("", Net::HTTP::Get::METHOD)

      raise ArgumentError, "Document ID can't be empty" if
        TypeUtilities.is_nil_or_whitespace?(document_id)

      raise ArgumentError, "Attachment name can't be empty" if
        TypeUtilities.is_nil_or_whitespace?(name)

      @_document_id = document_id
      @_name = name
      @_change_vector = change_vector
    end

    def create_request(server_node)
      assert_node(server_node)

      @params = {"id" => @_document_id, "name" => @_name}
      @end_point = "/databases/#{server_node.database}/attachments"
    end
  end

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

      return if TypeUtilities.is_nil_or_whitespace?(@_content_type)

      @headers["Content-Type"] = @_content_type
      @params["contentType"] = @_content_type
    end

    def to_request_options
      request = super()

      request.body = @_stream
      request
    end
  end

  class DeleteAttachmentCommand < AttachmentCommand
    def create_request(server_node)
      super(server_node)

      unless @_change_vector.nil?
        @headers["If-Match"] = "\"#{@_change_vector}\""
      end

      @method = Net::HTTP::Delete::METHOD
    end
  end

  class GetAttachmentCommand < AttachmentCommand
    def initialize(document_id, name, type, change_vector = nil)
      super(document_id, name, change_vector)

      raise ArgumentError, "Change Vector cannot be null for non-document attachment type" if
        @_change_vector.nil? && !AttachmentType.is_document(type)

      @_type = type
    end

    def create_request(server_node)
      super(server_node)

      return if AttachmentType.is_document(@_type)

      @payload = {"Type" => @_type, "ChangeVector" => @_change_vector}
      @method = Net::HTTP::Post::METHOD
    end

    def set_response(response)
      raise DocumentDoesNotExistException if
        response.is_a?(Net::HTTPNotFound)

      if response.json(false).nil?
        @_last_response = response
      else
        super.set_response(response)
      end

      attachment = response.body.force_encoding("ASCII-8BIT")
      content_type = try_get_header("Content-Type")
      hash = try_get_header("Attachment-Hash")
      change_vector = try_get_header("Etag")
      size = try_get_header("Attachment-Size")

      begin
        size = Integer(size || "")
      rescue StandardError
        size = 0
      end

      if "\"" == change_vector[0]
        change_vector = change_vector[1..-2]
      end

      {
        stream: attachment,
        attachment_details: {
          content_type: content_type,
          name: @_name,
          hash: hash,
          size: size,
          change_vector: change_vector,
          document_id: @_document_id
        }
      }
    end

    protected

    def try_get_header(header)
      if @_last_response.key?(header)
        @_last_response[header]
      elsif @_last_response.key?(header.downcase)
        @_last_response[header.downcase]
      end
    end
  end
end
