require "database/commands"

module RavenDB
  class GetDatabaseNamesCommand < RavenCommandUnified
    def initialize(start:, page_size:)
      super()
      @start = start
      @page_size = page_size
    end

    def create_request(server_node)
      assert_node(server_node)

      end_point = "/databases?start=#{@start}&pageSize=#{@page_size}&namesOnly=true"
      Net::HTTP::Get.new(end_point)
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
