module RavenDB
  class DeleteAttachmentCommand < AttachmentCommand
    def create_request(server_node)
      request = super(server_node)

      unless @_change_vector.nil?
        request["If-Match"] = "\"#{@_change_vector}\""
      end

      request
    end

    def http_method
      Net::HTTP::Delete
    end
  end
end
