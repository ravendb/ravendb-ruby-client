module RavenDB
  class CreateDatabaseCommand < RavenCommand
    def initialize(database_document, replication_factor = 1)
      super("", Net::HTTP::Put::METHOD)
      @database_document = database_document || nil
      @replication_factor = replication_factor || 1
    end

    def create_request(server_node)
      db_name = @database_document.database_id.gsub("Raven/Databases/", "")
      assert_node(server_node)

      if db_name.nil? || !db_name
        raise InvalidOperationException, "Empty name is not valid"
      end

      if /^[A-Za-z0-9_\-\.]+$/.match(db_name).nil?
        raise InvalidOperationException, "Database name can only contain only A-Z, a-z, \"_\", \".\" or \"-\""
      end

      if !@database_document.settings.key?("Raven/DataDir")
        raise InvalidOperationException, "The Raven/DataDir setting is mandatory"
      end

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
    def initialize(database_id, hard_delete = false, from_node = nil)
      super("", Net::HTTP::Delete::METHOD)
      @from_node = from_node
      @database_id = database_id
      @hard_delete = hard_delete
    end

    def create_request(server_node)
      db_name = @database_id.gsub("Raven/Databases/", "")
      @params = {"name" => db_name}
      @end_point = "/admin/databases"

      if @hard_delete
        add_params("hard-delete", "true")
      end

      if @from_node
        add_params("from-node",  @from_node.cluster_tag)
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
        return result
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
        return result
      end
    end
  end
end