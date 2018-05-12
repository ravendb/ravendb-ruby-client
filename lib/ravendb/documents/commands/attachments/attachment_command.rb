module RavenDB
  class AttachmentCommand < RavenCommand
    def initialize(document_id, name, change_vector = nil)
      super("", Net::HTTP::Get::METHOD)

      raise ArgumentError, "Document ID can't be empty" if document_id.blank?

      raise ArgumentError, "Attachment name can't be empty" if name.blank?

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
end
