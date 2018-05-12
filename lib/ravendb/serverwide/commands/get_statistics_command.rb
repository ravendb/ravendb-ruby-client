module RavenDB
  class GetStatisticsCommand < RavenCommand
    def initialize(check_for_failures = false)
      super("", Net::HTTP::Get::METHOD)
      @check_for_failures = check_for_failures
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "/databases/#{server_node.database}/stats"

      add_params("failure", "check") if @check_for_failures
    end

    def set_response(response)
      result = super(response)

      result if response.is_a?(Net::HTTPOK) && response.body
    end
  end
end
