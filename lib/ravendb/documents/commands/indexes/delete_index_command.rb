module RavenDB
  class DeleteIndexCommand < RavenCommand
    def initialize(index_name)
      super()
      @index_name = index_name
    end

    def create_request(server_node)
      assert_node(server_node)

      raise "nil or empty index_name is invalid" unless @index_name

      end_point = "/databases/#{server_node.database}/indexes?name=#{@index_name}"
      Net::HTTP::Delete.new(end_point)
    end
  end
end
