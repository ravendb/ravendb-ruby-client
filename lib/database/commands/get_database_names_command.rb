require "database/commands"

module RavenDB
  class GetDatabaseNamesCommand < RavenCommand
    def initialize(start:, page_size:)
      super("/databases?start=#{start}&pageSize=#{page_size}&namesOnly=true")
    end

    def create_request(server_node, url: nil)
      assert_node(server_node)

      if url
        url.value = @end_point
        request = Net::HTTP::Get.new(url.value)
        request
      end
    end

    def set_response(response)
      response = super(response)

      raise_invalid_response! unless response.is_a?(Hash)

      parse_response(response, from_cache: nil)
    end

    def parse_response(json, from_cache:)
      response = json

      raise_invalid_response! unless response.key?("Databases")

      databases = response["Databases"]

      raise_invalid_response! unless databases.is_a?(Array)

      @result = databases
      databases
    end

    def read_request?
      true
    end
  end
end
