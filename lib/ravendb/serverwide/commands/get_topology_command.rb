module RavenDB
  class GetTopologyCommand < RavenCommand
    def initialize(force_url = nil)
      super("", Net::HTTP::Get::METHOD)
      @force_url = force_url
    end

    def create_request(server_node)
      assert_node(server_node)
      @params = {"name" => server_node.database}
      @end_point = "/topology"

      add_params("url", @force_url) if @force_url
    end

    def set_response(response)
      result = super(response)

      result if response.body && response.is_a?(Net::HTTPOK)
    end
  end
end
