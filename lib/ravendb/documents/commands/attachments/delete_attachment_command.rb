module RavenDB
  class DeleteAttachmentCommand < AttachmentCommand
    def create_request(server_node)
      super(server_node)

      unless @_change_vector.nil?
        @headers["If-Match"] = "\"#{@_change_vector}\""
      end

      @method = Net::HTTP::Delete::METHOD
    end
  end
end
