module RavenDB
  class CreateSampleDataCommand < RavenCommand
    def read_request?
      false
    end

    def create_request(server_node)
      end_point = (("/databases/" + server_node.database) + "/studio/sample-data")
      Net::HTTP::Post.new(end_point)
    end
  end
end
