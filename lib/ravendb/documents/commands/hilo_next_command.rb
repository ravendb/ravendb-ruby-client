module RavenDB
  class HiloNextCommand < RavenCommand
    def initialize(tag, last_batch_size, last_range_at, identity_parts_separator, last_range_max)
      super()
      @tag = tag
      @last_batch_size = last_batch_size
      @last_range_at = last_range_at
      @last_range_max = last_range_max
      @identity_parts_separator = identity_parts_separator
    end

    def create_request(server_node)
      params = {
        "tag" => @tag,
        "lastMax" => @last_range_max,
        "lastBatchSize" => @last_batch_size,
        "lastRangeAt" => TypeUtilities.stringify_date(@last_range_at),
        "identityPartsSeparator" => @identity_parts_separator
      }

      end_point = "/databases/#{server_node.database}/hilo/next?" + params.map { |k, v| "#{k}=#{v}" }.join("&")

      Net::HTTP::Get.new(end_point)
    end

    def parse_response(json, from_cache:, conventions: nil)
      result = json

      {
        "low" => result["Low"],
        "high" => result["High"],
        "prefix" => result["Prefix"],
        "last_size" => result["LastSize"],
        "server_tag" => result["ServerTag"],
        "last_range_at" => result["LastRangeAt"]
      }
    end

    def read_request?
      false
    end
  end
end
