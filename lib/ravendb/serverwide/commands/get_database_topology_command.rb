require "database/commands"

module RavenDB
  class GetDatabaseTopologyCommand < RavenCommand
    def initialize
      super(nil)
    end

    def create_request(server_node, url: nil)
      @end_point = "/topology?name=" + server_node.database
      if server_node.url.downcase.include?(".fiddler")
        # we want to keep the '.fiddler' stuff there so we'll keep tracking request
        # so we are going to ask the server to respect it
        @end_point += "&localUrl=" + CGI.escape(node.url)
      end
      assert_node(server_node)

      if url
        url.value = @end_point
        Net::HTTP::Get.new(url.value)
      end
    end

    def read_request?
      true
    end
  end
end
