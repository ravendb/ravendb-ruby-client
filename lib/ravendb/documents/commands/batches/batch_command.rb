module RavenDB
  class BatchCommand < RavenCommand
    def initialize(commands_array = [])
      super()
      @commands_array = commands_array
    end

    def create_request(server_node)
      commands = @commands_array
      assert_node(server_node)

      unless commands.all? { |data| data&.is_a?(RavenCommandData) }
        raise "Not a valid command"
      end

      end_point = "/databases/#{server_node.database}/bulk_docs"
      payload = {"Commands" => commands.map { |data| data.to_json }}

      request = Net::HTTP::Post.new(end_point, "Content-Type" => "application/json")
      request.body = payload.to_json
      request
    end

    def set_response(response)
      result = super(response)

      unless response.body
        raise "Invalid response body received"
      end

      result["Results"]
    end
  end
end
