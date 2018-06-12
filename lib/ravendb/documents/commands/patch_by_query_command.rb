module RavenDB
  class PatchByQueryCommand < QueryBasedCommand
    def initialize(query_to_update, options = nil)
      super(query_to_update, options)
    end

    def payload
      {
        "Query" => @query.to_json
      }
    end

    def http_method
      Net::HTTP::Patch
    end

    def read_request?
      false
    end
  end
end
