module RavenDB
  class AttachmentCommand < RavenCommand
    def initialize(document_id, name, change_vector = nil)
      super()

      raise ArgumentError, "Document ID can't be empty" if document_id.blank?
      raise ArgumentError, "Attachment name can't be empty" if name.blank?

      @_document_id = document_id
      @_name = name
      @_change_vector = change_vector
    end

    def create_request(server_node)
      assert_node(server_node)

      end_point = "/databases/#{server_node.database}/attachments?" + params.map { |k, v| "#{k}=#{v}" }.join("&")

      request = if has_payload?
                  http_method.new(end_point, "Content-Type" => "application/json")
                else
                  http_method.new(end_point)
                end

      request
    end

    def has_payload?
      false
    end

    def payload
      nil
    end

    def params
      {"id" => @_document_id, "name" => @_name}
    end

    def http_method
      Net::HTTP::Get
    end
  end
end
