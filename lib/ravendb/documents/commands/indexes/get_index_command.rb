module RavenDB
  class GetIndexCommand < GetIndexesCommand
    def initialize(index_name)
      super()
      @index_name = index_name
    end

    def create_request(server_node)
      super(server_node)
      @params = {"name" => @index_name}
    end

    def set_response(response)
      results = super(response)

      results.first if results.is_a?(Array)
    end
  end
end
