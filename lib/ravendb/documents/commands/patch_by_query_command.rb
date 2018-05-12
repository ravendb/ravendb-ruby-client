module RavenDB
  class PatchByQueryCommand < QueryBasedCommand
    def initialize(query_to_update, options = nil)
      super(Net::HTTP::Patch::METHOD, query_to_update, options)
    end

    def create_request(server_node)
      super(server_node)

      @payload = {
          "Query" => @query.to_json
      }
    end
  end
end
