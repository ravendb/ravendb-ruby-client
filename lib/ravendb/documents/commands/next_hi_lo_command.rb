module RavenDB
  class NextHiLoCommand < RavenCommand
    def initialize(tag, last_batch_size, last_range_at, identity_parts_separator, last_range_max)
      super()

      raise ArgumentError, "tag cannot be null" if tag.nil?
      if identity_parts_separator.nil?
        raise ArgumentError, "identityPartsSeparator cannot be null"
      end
      @_tag = tag
      @_last_batch_size = last_batch_size
      @_last_range_at = last_range_at
      @_identity_parts_separator = identity_parts_separator
      @_last_range_max = last_range_max
    end

    def create_request(node)
      params = {
        "tag" => @_tag,
        "lastBatchSize" => @_last_batch_size,
        "lastRangeAt" => @_last_range_at,
        "identityPartsSeparator" => @_identity_parts_separator,
        "lastMax" => @_last_range_max
      }

      url = "/databases/#{node.database}/hilo/next?" + URI.encode_www_form(params)
      Net::HTTP::Get.new(url)
    end

    def parse_response(json, from_cache:, conventions:)
      @mapper.read_value(json, HiLoResult, conventions: conventions)
    end

    def read_request?
      true
    end
  end
end
