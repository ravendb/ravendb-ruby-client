module RavenDB
  class GetIndexesCommand < RavenCommand
    def initialize(start = 0, page_size = 10)
      super("", Net::HTTP::Get::METHOD, nil, nil, {})
      @start = start
      @page_size = page_size
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "/databases/#{server_node.database}/indexes"
      @params = {"start" => @start, "page_size" => @page_size}
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPNotFound)
        raise IndexDoesNotExistException, "Can't find requested index(es)"
      end

      unless response.body
        return
      end

      result["Results"]
    end
  end
end
