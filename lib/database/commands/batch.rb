module RavenDB
  class BatchCommand < RavenCommand
    def initialize(commands_array = [])
      super("", Net::HTTP::Post::METHOD)
      @commands_array = commands_array
    end

    def create_request(server_node)
      commands = @commands_array
      assert_node(server_node)

      unless commands.all? { |data| data&.is_a?(RavenCommandData) }
        raise "Not a valid command"
      end

      @end_point = "/databases/#{server_node.database}/bulk_docs"
      @payload = {"Commands" => commands.map { |data| data.to_json }}
    end

    def set_response(response)
      result = super(response)

      unless response.body
        raise "Invalid response body received"
      end

      result["Results"]
    end
  end

  class DeleteCommandData < RavenCommandData
    def initialize(id, change_vector = nil)
      super(id, change_vector)
      @type = Net::HTTP::Delete::METHOD
    end
  end

  class PatchCommandData < RavenCommandData
    def initialize(id, scripted_patch, change_vector = nil, patch_if_missing = nil, debug_mode = nil)
      super(id, change_vector)

      @type = Net::HTTP::Patch::METHOD
      @scripted_patch = scripted_patch || nil
      @patch_if_missing = patch_if_missing
      @debug_mode = debug_mode
      @additional_data = nil
    end

    def to_json
      json = super().merge(
        "Patch" => @scripted_patch.to_json,
        "DebugMode" => @debug_mode
      )

      unless @patch_if_missing.nil?
        json["PatchIfMissing"] = @patch_if_missing.to_json
      end

      json
    end
  end

  class PutCommandData < RavenCommandData
    def initialize(id, document, change_vector = nil, metadata = nil)
      super(id, change_vector)

      @type = Net::HTTP::Put::METHOD
      @document = document || nil
      @metadata = metadata
    end

    def to_json
      json = super()
      document = @document

      if @metadata
        document["@metadata"] = @metadata
      end

      json["Document"] = document
      json
    end
  end

  class SaveChangesData
    attr_reader :deferred_commands_count

    def commands_count
      @commands.size
    end

    def initialize(commands = nil, deferred_command_count = 0, documents = nil)
      @commands = commands || []
      @documents = documents || []
      @deferred_commands_count = deferred_command_count
    end

    def add_command(command)
      @commands.push(command)
    end

    def add_document(document)
      @documents.push(document)
    end

    def get_document(index)
      @documents.at(index)
    end

    def create_batch_command
      BatchCommand.new(@commands)
    end
  end
end
