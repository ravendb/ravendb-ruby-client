module RavenDB
  class DatabaseDocument
    attr_reader :database_id, :settings

    def initialize(database_id, settings = {}, disabled = false, encrypted = false)
      @database_id = database_id || nil
      @settings = settings
      @disabled = disabled
      @encrypted = encrypted
    end

    def to_json
      {
        "DatabaseName" => @database_id,
        "Disabled" => @disabled,
        "Encrypted" => @encrypted,
        "Settings" => @settings
      }
    end
  end

  class CreateDatabaseCommand < RavenCommand
    def initialize(database_document, replication_factor = 1)
      super("", Net::HTTP::Put::METHOD)
      @database_document = database_document || nil
      @replication_factor = replication_factor || 1
    end

    def create_request(server_node)
      db_name = @database_document.database_id.gsub("Raven/Databases/", "")
      assert_node(server_node)

      @params = {"name" => db_name, "replication-factor" => @replication_factor}
      @end_point = "/admin/databases"
      @payload = @database_document.to_json
    end

    def set_response(response)
      result = super(response)

      if !response.body
        raise ErrorResponseException, "Response is invalid."
      end

      result
    end
  end

  class DeleteDatabaseCommand < RavenCommand
    def initialize(database_id, hard_delete = false, from_node = nil, time_to_wait_for_confirmation = nil)
      super("", Net::HTTP::Delete::METHOD)

      @database_id = database_id
      @from_node = from_node || nil
      @hard_delete = hard_delete || false
      @time_to_wait_for_confirmation = time_to_wait_for_confirmation || nil

      if @from_node.is_a?(ServerNode)
        @from_node = from_node.cluster_tag
      end
    end

    def create_request(server_node)
      db_name = @database_id.gsub("Raven/Databases/", "")
      @end_point = "/admin/databases"

      @payload = {
        "DatabaseNames" => [db_name],
        "HardDelete" => @hard_delete,
        "TimeToWaitForConfirmation" => @time_to_wait_for_confirmation
      }

      if @from_node
        @payload["FromNodes"] = [@from_node]
      end
    end
  end

  class GetTopologyCommand < RavenCommand
    def initialize(force_url = nil)
      super("", Net::HTTP::Get::METHOD)
      @force_url = force_url
    end

    def create_request(server_node)
      assert_node(server_node)
      @params = {"name" => server_node.database}
      @end_point = "/topology"

      if @force_url
        add_params("url", @force_url)
      end
    end

    def set_response(response)
      result = super(response)

      if response.body && response.is_a?(Net::HTTPOK)
        result
      end
    end
  end

  class GetClusterTopologyCommand < GetTopologyCommand
    def create_request(server_node)
      super(server_node)
      remove_params("name")
      @end_point = "/cluster/topology"
    end
  end

  class GetOperationStateCommand < RavenCommand
    def initialize(id)
      super("", Net::HTTP::Get::METHOD)
      @id = id || nil
    end

    def create_request(server_node)
      assert_node(server_node)
      @params = {"id" => @id}
      @end_point = "/databases/#{server_node.database}/operations/state"
    end

    def set_response(response)
      result = super(response)

      if response.body
        return result
      end

      raise ErrorResponseException, "Invalid server response"
    end
  end

  class GetStatisticsCommand < RavenCommand
    def initialize(check_for_failures = false)
      super("", Net::HTTP::Get::METHOD)
      @check_for_failures = check_for_failures
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "/databases/#{server_node.database}/stats"

      if @check_for_failures
        add_params("failure", "check")
      end
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPOK) && response.body
        result
      end
    end
  end
end