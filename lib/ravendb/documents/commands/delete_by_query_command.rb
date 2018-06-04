module RavenDB
  class DeleteByQueryCommand < QueryBasedCommand
    def initialize(query, options = nil)
      super(query, options)
    end

    def payload
      @query.to_json
    end

    def http_method
      Net::HTTP::Delete
    end
  end
end
