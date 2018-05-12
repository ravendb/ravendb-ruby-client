module RavenDB
  class HiloReturnCommand < RavenCommand
    def initialize(tag, last_value, end_of_range)
      super("", Net::HTTP::Put::METHOD)
      @tag  = tag
      @last = last_value
      @end  = end_of_range
    end

    def create_request(server_node)
      @headers["Content-Type"] = "application/json"
      @params = {"tag" => @tag, "last" => @last, "end" => @end}
      @end_point = "/databases/#{server_node.database}/hilo/return"
    end
  end
end
