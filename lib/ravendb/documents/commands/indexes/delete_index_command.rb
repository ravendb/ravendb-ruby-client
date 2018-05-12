module RavenDB
  class DeleteIndexCommand < RavenCommand
    def initialize(index_name)
      super("", Net::HTTP::Delete::METHOD)
      @index_name = index_name
    end

    def create_request(server_node)
      assert_node(server_node)

      unless @index_name
        raise "nil or empty index_name is invalid"
      end

      @params = {"name" => @index_name}
      @end_point = "/databases/#{server_node.database}/indexes"
    end
  end
end
