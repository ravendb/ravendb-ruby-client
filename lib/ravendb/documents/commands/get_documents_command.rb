module RavenDB
  class GetDocumentsCommand < RavenCommand
    def initialize(ids: nil, includes: nil, start_with: nil, start_after: nil, matches: nil, exclude: nil, start: nil, page_size: nil, metadata_only:)
      super()
      if start_with.nil? && (ids.nil? || ids.empty?)
        raise ArgumentError, "Please supply at least one id or startWith cannot be null"
      end
      @_ids = ids
      @_includes = includes
      @_start_with = start_with
      @_start_after = start_after
      @_matches = matches
      @_exclude = exclude
      @_start = start
      @_page_size = page_size
      @_metadata_only = metadata_only
    end

    def create_request(server_node)
      assert_node(server_node)

      end_point = "/databases/#{server_node.database}/docs?"

      params = {
        "include" => @_includes,
        "startsWith" => @_start_with,
        "startAfter" => @_start_after,
        "matches" => @_matches,
        "exclude" => @_exclude,
        "start" => @_start,
        "pageSize" => @_page_size,
        "metadataOnly" => @_metadata_only
      }.compact

      if (@_ids.map { |id| id.size }).sum > 1024
        @payload = {"Ids" => @_ids}
        request = Net::HTTP::Post.new(end_point, "Content-Type" => "application/json")
        request.body = payload.to_json
        return request
      else
        params["id"] = @_ids
      end

      end_point += URI.encode_www_form(params)

      Net::HTTP::Get.new(end_point)
    end

    def read_request?
      true
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPNotFound)
        return
      end

      unless response.body
        raise ErrorResponseException, "Failed to load document from the database "\
  "please check the connection to the server"
      end

      result
    end
  end
end
