module RavenDB
  class HiloReturnCommand < RavenCommand
    def initialize(tag, last_value, end_of_range)
      super()
      @tag  = tag
      @last = last_value
      @end  = end_of_range
    end

    def create_request(server_node)
      params = {"tag" => @tag, "last" => @last, "end" => @end}
      end_point = "/databases/#{server_node.database}/hilo/return?" + URI.encode_www_form(params)

      request = Net::HTTP::Put.new(end_point)
      request["Content-Type"] = "application/json"
      request
    end
  end
end
