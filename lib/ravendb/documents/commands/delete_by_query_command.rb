module RavenDB
  class DeleteByQueryCommand < QueryBasedCommand
    def initialize(query, options = nil)
      super(Net::HTTP::Delete::METHOD, query, options)
    end

    def create_request(server_node)
      super(server_node)
      @payload = @query.to_json
    end
  end
end
