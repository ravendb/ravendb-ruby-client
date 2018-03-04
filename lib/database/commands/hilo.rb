module RavenDB
  class HiloNextCommand < RavenCommand
    def initialize(tag, last_batch_size, last_range_at, identity_parts_separator, last_range_max)
      super("", Net::HTTP::Get::METHOD)
      @tag = tag
      @last_batch_size = last_batch_size
      @last_range_at = last_range_at
      @last_range_max = last_range_max
      @identity_parts_separator = identity_parts_separator
    end

    def create_request(server_node)
      @params = {
          "tag" => @tag,
          "lastMax" => @last_range_max,
          "lastBatchSize" => @last_batch_size,
          "lastRangeAt" => TypeUtilities::stringify_date(@last_range_at),
          "identityPartsSeparator" => @identity_parts_separator
      }

      @end_point = "/databases/#{server_node.database}/hilo/next"
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPCreated)
        return {
          "low" => result["Low"],
          "high" => result["High"],
          "prefix" => result["Prefix"],
          "last_size" => result["LastSize"],
          "server_tag" => result["ServerTag"],
          "last_range_at" => result["LastRangeAt"]
        }
      end

      raise ErrorResponseException, "Something is wrong with the request"
    end
  end

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
      @end_point ="/databases/#{server_node.database}/hilo/return"
    end
  end
end