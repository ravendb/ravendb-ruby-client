require "set"
require "uri"
require "json"
require "net/http"
require "utilities/json"
require "database/auth"
require "database/exceptions"
require "documents/document_query"
require "requests/request_helpers"

module RavenDB
  class RavenCommand
    @method = Net::HTTP::Get::METHOD
    @end_point = ""
    @params = {}
    @payload = nil
    @headers = {}
    @failed_nodes = nil
    @_last_response = {}

    def initialize(end_point, method=Net::HTTP::Get::METHOD, params={}, payload=nil, headers={})
      @end_point = end_point
      @method = method
      @params = params
      @payload = payload
      @headers = headers
      @failed_nodes = Set.new([])  
    end

    def server_response
      return @_last_response
    end  

    def was_failed()
      !@failed_nodes.empty?
    end

    def add_failed_node(node)
      assert_node(node)
      @failed_nodes.add(node)
    end

    def was_failed_with_node(node)
      assert_node(node)
      return @failed_nodes.include?(node)
    end

    def create_request(server_node)
      raise NotImplementedError, "You should implement create_request method"
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
      raise ArgumentError, "Argument \"node\" should be an instance of ServerNode" unless json.is_a? ServerNode
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
      super("", Net::HTTP::Post::METHOD)
      @commands_array = commands_array
    end

    def create_request(server_node)
      commands = @commands_array
      assert_node(server_node)

      if !commands.all? { |data| data && data.is_a?(RavenCommandData) }
        raise InvalidOperationException, "Not a valid command"
      end

      @end_point = "#{server_node.url}/databases/#{server_node.database}/bulk_docs"
      @payload = {"Commands" => commands.map { |data| data.to_json }}
    end

    def set_response(response)
      result = super(response)

      if !response.body
        raise InvalidOperationException, "Invalid response body received"
      end

      return result["Results"]
    end
  end

  class CreateDatabaseCommand < RavenCommand
    @replication_factor = 1
    @database_document = nil

    def initialize(database_document, replication_factor = 1)
      super("", Net::HTTP::Put::METHOD)
      @database_document = database_document
      @replication_factor = replication_factor || 1
    end

    def create_request(server_node)
      db_name = @database_document.database_id.sub! "Raven/Databases/", ""
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
      @end_point = "#{server_node.url}/admin/databases"
      @payload = @database_document.to_json
    end

    def set_response(response)
      result = super.set_response(response)

      if !response.body
        raise ErrorResponseException, "Response is invalid."
      end

      return result
    end
  end

  class IndexQueryBasedCommand < RavenCommand
    @query = nil
    @options = nil

    def initialize(method, query, options = nil)
      super("", method)
      @query = query
      @options = options || QueryOperationOptions.new
    end

    def create_request(server_node)
      assert_node(server_node)
      query = @query
      options = @options

      if !query.is_a?(IndexQuery)
        raise InvalidOperationException, "Query must be instance of IndexQuery class"
      end

      if !options.is_a(QueryOperationOptions)
        raise InvalidOperationException, "Options must be instance of QueryOperationOptions class"
      end

      @params = {
        "pageSize" => query.page_size,
        "allowStale" => options.allow_stale,
        "details" => options.retrieve_details
      }

      @end_point = @end_point + "/queries"
      
      if query.query
        add_params("Query", query.query)
      end

      if options.max_ops_per_sec
        add_params("maxOpsPerSec", options["max_ops_per_sec"])
      end  

      if options.stale_timeout
        add_params("staleTimeout", options["stale_timeout"])
      end  
    end
  end

  class DeleteByIndexCommand < IndexQueryBasedCommand
    def initialize(query, options = nil)
      super(Net::HTTP::Delete::METHOD, query, options)
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "#{server_node.url}/databases/#{server_node.database}"
      super(serverNode)
    end

    def set_response(response)
      result = super(response)

      if !response.body
        raise IndexDoesNotExistException, "Could not find index"
      end

      return result
    end
  end

  class DeleteDatabaseCommand < RavenCommand
    @database_id = nil
    @hard_delete = false
    @from_node = nil

    def initialize(database_id, hard_delete = false, from_node = nil)
      super("", Net::HTTP::Delete::METHOD)
      @from_node = from_node
      @database_id = database_id
      @hard_delete = hard_delete
    end

    def create_request(server_node)
      db_name = @database_document.database_id.sub! "Raven/Databases/", ""
      @params = {"name" => db_name}
      @end_point = "#{server_node.url}/admin/databases"

      if @hard_delete
        add_params("hard-delete", "true")
      end

      if from_node
        add_params("from-node",  from_node.cluster_tag)
      end      
    end
  end

  class DeleteDocumentCommand < RavenCommand
    @id = nil
    @change_vector = nil

    def initialize(id, change_vector = nil)
      super("", Net::HTTP::Delete::METHOD)

      @id = id;
      @change_vector = change_vector
    end

    def create_request(server_node)
      assert_node(server_node)

      if !@id
        raise InvalidOperationException, "Null Id is not valid"
      end

      if !@id.is_a(String)
        raise InvalidOperationException, "Id must be a string"
      end

      if @change_vector
        @headers = {"If-Match" => "\"#{@change_vector}\""}
      end

      @params = {"id" => @id}
      @end_point = "#{server_node.url}/databases/#{server_node.database}/docs"
    end

    def set_response(response)
      super(response)
      check_response(response)
    end

    protected 
    def check_response(response)
      if !response.is_a(Net::HTTPNoConent)
        raise InvalidOperationException, "Could not delete document #{@id}"
      end
    end
  end  

  class DeleteIndexCommand < RavenCommand
    @index_name = nil

    def initialize(index_name)
      super("", Net::HTTP::Delete::METHOD)
      @index_name = index_name
    end

    def create_request(server_node)
      assert_node(server_node)

      if !@index_name
        raise InvalidOperationException, "Null or empty index_name is invalid"
      end

      @params = {"name" => index_name}
      @end_point = "#{server_node.url}/databases/#{server_node.database}/indexes"
    end
  end

  class GetApiKeyCommand < RavenCommand
    @name = nil

    def initialize(name)
      super("", Net::HTTP::Get::METHOD)

      if !name
        raise InvalidOperationException, "Api key name isn't set"
      end

      @name = name
    end

    def create_request(server_node)
      assert_node(server_node)
      @params = {"name" => @name}
      @end_point = "#{server_node.url}/admin/api-keys"
    end

    def set_response(response)
      result = super(response)
      
      if result && result["Results"]
        return result["Results"]
      end

      raise ErrorResponseException, "Invalid server response"
    end
  end

  class GetTopologyCommand < RavenCommand
    @force_url = nil

    def initialize(force_url = nil)
      super("", Net::HTTP::Get::METHOD)
      @force_url = force_url
    end

    def create_request(server_node)
      assert_node(server_node)
      @params = {"name" => server_node.database}
      @end_point = "#{server_node.url}/topology"

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
      @end_point = "#{server_node.url}/cluster/topology"
    end
  end

  class GetDocumentCommand < RavenCommand
    @id_or_ids = []
    @includes = nil
    @metadata_only = false

    def initialize(id_or_ids, includes = nil, metadata_only = false)
      super("", Net::HTTP::Get::METHOD, nil, nil, {});

      @id_or_ids = id_or_ids
      @includes = includes
      @metadata_only = metadata_only
    end

    def create_request(server_node)
      assert_node(server_node)

      if !@id_or_ids
        raise InvalidOperationException, "Null ID is not valid"
      end
      
      ids = @id_or_ids.is_a(Array) ? @id_or_ids : [@id_or_ids]
      first_id = ids.first
      multi_load = ids.size > 1 

      @params = {}
      @end_point = "#{server_node.url}/databases/#{server_node.database}/docs"
      
      if @includes
        add_params("include", @includes)
      end        
      
      if multiLoad
        if @metadata_only
          add_params("metadata-only", "True")
        end  

        if (ids.map { |id| id.size }).sum > 1024
          @payload = {"Ids" => ids}
          @method = Net::HTTP::Post::METHOD          
        end
      end

      add_params("id", multi_load ? ids : first_id);
    end

    def set_response(response)
      result = super(response);   

      if response.is_a?(Net::HTTPNotFound)
        return;
      end

      if !response.body
        raise ErrorResponseException, "Failed to load document from the database "\
  "please check the connection to the server"
      end

      return result
    end
  end

  class GetIndexesCommand < RavenCommand
    @start = nil
    @page_size = nil

    def initialize(start = 0, page_size = 10)
      super("", Net::HTTP::Get::METHOD, null, null, {})
      @start = start
      @page_size = page_size
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "#{server_node.url}/databases/#{server_node.database}/indexes"
      @params = { "start" => @start, "page_size" => @page_size }
    end

    def set_response(response)
      result = super(response)

      if response.is_a?(Net::HTTPNotFound)
        raise IndexDoesNotExistException, "Can't find requested index(es)"
      end

      if !response.body
        return;
      end

      return result["Results"]
    end
  end

  class GetIndexCommand < GetIndexesCommand
    @index_name = nil

    def initialize(index_name)
      super
      @index_name = index_name
    end

    def create_request(server_node)
      super(server_node)
      @params = {"name" => @index_name}
    end

    def set_response(response)
      results = super(response)

      if results.is_a?(Array)
        return results.first
      end
    end
  end

  class GetOperationStateCommand < RavenCommand
    @id = nil

    def initialize(id)
      super("", Net::HTTP::Get::METHOD)
      @id = id
    end

    def create_request(server_node)
      assert_node(server_node)
      @params = {"id" => @id}
      @end_point = "#{server_node.url}/databases/#{server_node.database}/operations/state"
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
    @check_for_failures = nil

    def initialize(check_for_failures = false)
      super("", Net::HTTP::Get::METHOD)
      @check_for_failures = check_for_failures
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "#{server_node.url}/databases/#{server_node.database}/stats"
      
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

  class PatchByIndexCommand < IndexQueryBasedCommand
    @patch = nil

    def initialize(query_to_update, patch = nil, options = nil)
      super(Net::HTTP::Patch::METHOD, query_to_update, options)
      @patch = patch
    end

    def create_request(server_node)
      assert_node(server_node)

      if !@patch.is_a?(PatchRequest)
        raise InvalidOperationException, "Patch must be instanceof PatchRequest class"
      end

      @payload = @patch.to_json
      @end_point = "{url}/databases/{database}"
      super(server_node)
    end

    def set_response(response)
      result = super(response)

      if !response.body
        raise IndexDoesNotExistException, "Could not find index"
      end

      if !response.is_a?(Net::HTTPOK) && !response.is_a?(Net::HTTPAccepted)
        raise ErrorResponseException, "Invalid response from server"
      end

      return result
    end
  end

  class PatchCommand < RavenCommand
    @id = nil
    @patch = nil
    @change_vector = nil
    @patch_if_missing = nil
    @skip_patch_if_change_vector_mismatch = nil
    @return_debug_information = nil

    def initialize(id, patch, options = nil)
      super('', Net::HTTP::Patch::METHOD)
      opts = options || {}

      @id = id
      @patch = patch
      @change_vector = opts["change_vector"]
      @patch_if_missing = opts["patch_if_missing"]
      @skip_patch_if_change_vector_mismatch = opts["skip_patch_if_change_vector_mismatch"] || false
      @return_debug_information = opts["return_debug_information"] || false
    end

    def create_request(server_node)
      assert_node(server_node)

      if @id.nil?
        raise InvalidOperationException, 'Empty ID is invalid'
      end

      if @patch.nil?
        raise InvalidOperationException, 'Empty patch is invalid'
      end

      if @patch_if_missing && !@patch_if_missing.script
        raise InvalidOperationException, 'Empty script is invalid'
      end

      @params = {"id" => @id}
      @end_point = StringUtil.format('{url}/databases/{database}/docs', serverNode);

      if @skip_patch_if_change_vector_mismatch
        add_params('skipPatchIfChangeVectorMismatch', 'true')
      end  

      if @return_debug_information
        add_params('debug', 'true')
      end  

      if !@change_vector.nil?
        @headers = {"If-Match" => "\"#{@change_vector}\""}
      end  

      @payload = {
        "Patch" => @patch.to_json,
        "PatchIfMissing" => @patch_if_missing ? @patch_if_missing.to_json : nil
      }
    end

    def set_response(response)
      result = super(response)

      if !response.is_a?(Net::HTTPOK) && !response.is_a?(Net::HTTPNotModified)
        raise InvalidOperationException, "Could not patch document #{@id}"
      end

      if response.body
        return result
      end
    end
  end

  class PutApiKeyCommand < RavenCommand
    @name = nil
    @api_key = nil

    def initialize(name, api_key)
      super('', Net::HTTP::Put::METHOD)

      if !name
        raise InvalidOperationException, 'Api key name isn\'t set'
      end

      if !api_key
        raise InvalidOperationException, 'Api key definition isn\'t set'
      end

      if !api_key.is_a?(ApiKeyDefinition)
        raise InvalidOperationException, 'Api key definition mus be an instance of ApiKeyDefinition'
      end

      @name = name
      @api_key = api_key
    end

    def create_request(server_node)
      assert_node(server_node)

      @params = {"name" => @name}
      @payload = @api_key.to_json
      @end_point = "#{server_node.url}/admin/api-keys"
    end
  end

  class PutDocumentCommand < DeleteDocumentCommand
    @document = nil

    def initialize(id, document, change_vector = nil)
      super(id, change_vector)

      @document = document
      @method = Net::HTTP::Put::METHOD
    end

    def create_request(server_node)
      if !@document
        raise InvalidOperationException, 'Document must be an object'
      end

      @payload = @document;
      super(server_node);
    end

    def set_response(response)
      super(response)
      return response.body
    end

    protected
    def check_response(response)
      if !response.body
        raise ErrorResponseException, "Failed to store document to the database "\
  "please check the connection to the server"
      end
    end
  end

  class PutIndexesCommand < RavenCommand
    @indexes = []

    def initialize(indexes_to_add, *more_indexes_to_add)
      indexes = indexes_to_add.is_a?(Array) ? indexes_to_add : [indexes_to_add]

      if more_indexes_to_add.is_a?(Array) && !more_indexes_to_add.empty?
        indexes = indexes.concat(more_indexes_to_add)
      end
      
      super('', Net::HTTP::Put::METHOD)

      if indexes.empty?
        raise InvalidOperationException, 'No indexes specified'
      end

      indexes.each do |index|
        if !index.is_a(IndexDefinition)
          raise InvalidOperationException, 'All indexes should be instances of IndexDefinition'
        end

        if !index.name
          raise InvalidOperationException, 'All indexes should have a name'
        end

        @indexes.push(index)
      end
    end

    def create_request(server_node)
      assert_node(server_node)
      @end_point = "#{server_node.url}/databases/#{server_node.database}/indexes"
      @payload = {"Indexes": @indexes.map { |index| index.to_json }}
    end

    def set_response(response)
      result = super(response)

      if !response.body
        throw raise ErrorResponseException, "Failed to put indexes to the database "\
  "please check the connection to the server"
      end
      
      return result
    end
  end

  class QueryCommand < RavenCommand
    @index_name = nil
    @index_query = nil
    @conventions = nil
    @includes = []
    @metadata_only = false
    @index_entries_only = false

    def initialize(index_query, conventions, includes = nil, metadata_only = false, index_entries_only = false)
      super('', RequestMethods.Post, null, null, {})

      if !indexName
        raise InvalidOperationException, 'Index name cannot be empty'
      end

      if !indexQuery.is_a?(IndexQuery)
        raise InvalidOperationException, 'Query must be an instance of IndexQuery class'
      end

      if !conventions
        raise InvalidOperationException, 'Document conventions cannot be empty'
      end

      @index_query = index_query
      @conventions = conventions
      @includes = includes
      @metadata_only = metadata_only
      @index_entries_only = index_entries_only
    end

    def create_request(server_node)
      assert_node(server_node)

      query = @index_query
      @payload = { "PageSize" => query.page_size, "Start" => query.start }
      @endPoint = "#{server_node.url}/databases/#{server_node.database}/queries"

      if query.query
        @payload["Query"] = query.query
      end

      if query.fetch
        add_params('fetch', query.fetch)
      end  

      if @includes
        add_params('include', @includes)
      end
      
      if @metadata_only 
        add_params('metadata-only', 'true')
      end

      if @index_entries_only
        add_params('debug', 'entries')
      end
      
      if query.sort_fields
        add_params('sort', query.sort_fields)
      end
      
      if query.sort_hints
        query.sort_hints.each{ |hint| add_params(hint, null) }
      end

      if RQLJoinOperator.isAnd(query.default_operator)
        add_params('operator', query.default_operator)
      end  

      if query.wait_for_non_stale_results
        @payload = @payload.merge({
          waitForNonStaleResultsAsOfNow: 'true',
          waitForNonStaleResultsTimeout: query.wait_for_non_stale_results_timeout
        })
      end
    end

    def set_response(response)
      result = super(response)

      if !response.body
        raise IndexDoesNotExistException, "Could not find index"
      end

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

      if @metadata
        document["@metadata"] = @metadata
      end

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