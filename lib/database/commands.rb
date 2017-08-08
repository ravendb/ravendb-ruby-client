require 'set'
require 'uri'
require 'json'
require 'net/http'
require 'utilities/json'
require 'database/exceptions'
require 'requests/request_helpers'

module RavenDB
  class RavenCommand
    @method = Net::HTTP::Get::METHOD
    @end_point = ""
    @params = {}
    @payload = nil
    @headers = {}
    @failed_nodes = nil;
    @_last_response = {};

    def server_response
      @_last_response
    end  

    def initialize(end_point, method = Net::HTTP::Get::METHOD, params = {}, payload = nil, headers = {})
      @end_point = end_point;
      @method = method;
      @params = params;
      @payload = payload;
      @headers = headers;
      @failed_nodes = Set.new [];
    end

    def was_failed()
      !@failed_nodes.empty?
    end
  
    def add_failed_node(node)
      assert_node(node)
      @failed_nodes.add(node);
    end
  
    def was_failed_with_node(node)
      assert_node(node)
      return @failed_nodes.include?(node);
    end

    def create_request(server_node)
      raise NotImplementedError, 'You should implement create_request method'
    end  

    def to_request_options
      end_point = @end_point

      if !@params.empty?        
        encoded_params = URI.encode_www_form(@params)
        end_point = "#{end_point}?#{encoded_params}"
      end

      requestCtor = Object.const_get("Net::HTTP::#{@method}")
      request = requestCtor.new(end_point)

      if !@payload.nil? && !@payload.empty?
        request.body(JSON.generate(@payload))
      end      

      headers.each do |header, value|
        request.add_field(header, value)
      end

      return request
    end  

    def set_response(response)
      @_last_response = response.json

      if @_last_response
        ExceptionsRaiser.try_raise_from(response)
        return @_last_response
      end   
    end  

    protected
    def assert_node(node)
      raise ArgumentError, 'Argument "node" should be an instance of ServerNode' unless json.is_a? ServerNode
    end

    protected
    def add_params(param_or_params, value)      
      new_params = param_or_params

      if !new_params.is_a?(Hash)
        new_params = Hash.new
        new_params[paramOrParams] = value
      end    

      @params = @params.merge(new_params)
    end

    protected
    def remove_params(param_or_params, *other_params)
      remove = param_or_params

      if !remove.is_a?(Array)
        remove = [remove]
      end  

      if !other_params.empty?        
        remove = remove.concat(other_params)
      end

      remove.each {|param| @params.delete(param)}
    end  
  end  

  class BatchCommand < RavenCommand
    @commands_array = []

    def initialize(commands_array)
      super('', Net::HTTP::Post::METHOD)
      @commands_array = commands_array
    end

    def create_request(server_node)
      commands = @commands_array
      assert_node(server_node)

      if !commands.all? { |data| data && data.is_a?(RavenCommandData) }
        raise InvalidOperationException, 'Not a valid command'
      end

      @end_point = "#{server_node.url}/databases/#{server_node.database}/bulk_docs"
      @payload = {"Commands" => commands.map({ |data| data.to_json })}
    end

    def set_response(response)
      result = super(response)

      if !response.body {
        raise InvalidOperationException, 'Invalid response body received'
      }

      return result["Results"]
    end
  end

  class CreateDatabaseCommand < RavenCommand
    @replication_factor = 1
    @database_document = nil
    @from_node = nil

    def initialize(database_document, replication_factor = 1, from_node = nil) {
      super('', Net::HTTP::Put::METHOD)
      @database_document = database_document
      @replication_factor = replication_factor || 1
      @from_node = from_node
    end

    def create_request(server_node)
      dbName = @databaseDocument.database_id.sub! 'Raven/Databases/', ''
      assert_node(server_node)

      if dbName.nil? || !dbName
        raise InvalidOperationException, 'Empty name is not valid'
      end

      if /^[A-Za-z0-9_\-\.]+$/.match(dbName).nil?
        raise InvalidOperationException, 'Database name can only contain only A-Z, a-z, \"_\", \".\" or \"-\"'
      end

      if !@databaseDocument.settings.key?('Raven/DataDir') 
        raise InvalidOperationException, "The Raven/DataDir setting is mandatory"
      end

      @params = {"name" => dbName, "replication-factor" => @replication_factor}
      @end_point = "#{server_node.url}/admin/databases"
      @payload = @database_document.to_json
    end

    def set_response(response)
      result = super.set_response(response)

      if (!response.body) {
        raise ErrorResponseException, 'Response is invalid.'
      }

      return result
    end
  end

  class RavenCommandData
    @type = nil
    @id = nil
    @change_vector = nil;

    def initialize(id, change_vector)
      @id = id
      @change_vector = change_vector;
    end

    def document_id
      @id
    end

    def to_json
      return {
        "Type" => @type,
        "Id" => @id,
        "ChangeVector" => @change_vector
      }
    end
  end

  class DeleteCommandData < RavenCommandData
    def initialize(id, change_vector = nil)
      super(id, change_vector)
      @type = Net::HTTP::Delete::METHOD
    end
  end

  class PatchCommandData < RavenCommandData
    @scripted_patch = nil
    @patch_if_missing = nil
    @additional_data = nil
    @debug_mode = false

    def initialize(id, scripted_patch, change_vector, patch_if_missing = nil, debug_mode = nil)
      super(id, changeVector)

      @type = Net::HTTP::Patch::METHOD
      @scripted_patch = scripted_patch
      @patch_if_missing = patch_if_missing
      @debug_mode = debug_mode
    end

    def to_json
      json = super().merge({
        "Patch" => @scripted_patch.to_json,
        "DebugMode" => @debug_mode
      })
            
      if !@patch_if_missing.nil?
        json["PatchIfMissing"] = @patch_if_missing.to_json
      end

      return json
    end
  end

  class PutCommandData < RavenCommandData
    @document = nil
    @metadata = nil

    def initialize(id, document, change_vector = nil, metadata = nil)
      super(id, change_vector)

      @type = Net::HTTP::Put::METHOD
      @document = document
      @metadata = metadata
    end

    def to_json
      json = super()
      document = @document

      if (@metadata) {
        document["@metadata"] = @metadata
      }

      json["Document"] = document
      return json
    end
  end

  class SaveChangesData
    @commands = []
    @deferred_command_count = 0
    @documents = []

    def deferred_commands_count
      @deferred_command_count
    end

    def commands_count
      return @commands.size
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
      return @documents.at(index)
    end

    def create_batch_command
      return BatchCommand.new(@commands)
    end
  end
end