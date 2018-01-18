require "set"
require "uri"
require "json"
require 'date'
require "net/http"
require "utilities/json"
require "database/exceptions"
require 'documents/query/index_query'
require "documents/indexes"
require "requests/request_helpers"
require "utilities/type_utilities"
require "constants/documents"

module RavenDB
  class RavenCommand
    def initialize(end_point, method = Net::HTTP::Get::METHOD, params = {}, payload = nil, headers = {})
      @end_point = end_point || ""
      @method = method
      @params = params
      @payload = payload
      @headers = headers
      @failed_nodes = Set.new([])  
      @_last_response = nil      
    end

    def server_response
      @_last_response
    end  

    def was_failed?()
      !@failed_nodes.empty?
    end

    def add_failed_node(node)
      assert_node(node)
      @failed_nodes.add(node)
    end

    def was_failed_with_node?(node)
      assert_node(node)
      @failed_nodes.include?(node)
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

      requestCtor = Object.const_get("Net::HTTP::#{@method.capitalize}")
      request = requestCtor.new(end_point)

      if !@payload.nil? && !@payload.empty?
        begin
          request.body = JSON.generate(@payload)
        rescue JSON::GeneratorError
          raise RuntimeError, 'Invalid payload specified. Can be JSON object only'
        end
        @headers['Content-Type'] = 'application/json'
      end 
      
      if !@headers.empty?      
        @headers.each do |header, value|
          request.add_field(header, value)
        end
      end  

      request
    end  

    def set_response(response)
      @_last_response = response

      if @_last_response
        ExceptionsFactory.raise_from(response)
        response.json
      end   
    end  

    protected
    def assert_node(node)
      raise ArgumentError, "Argument \"node\" should be an instance of ServerNode" unless node.is_a? ServerNode
    end

    def add_params(param_or_params, value)      
      new_params = param_or_params

      if !new_params.is_a?(Hash)
        new_params = Hash.new
        new_params[param_or_params] = value
      end    

      @params = @params.merge(new_params)
    end

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

  class QueryBasedCommand < RavenCommand
    def initialize(method, query, options = nil)
      super("", method)
      @query = query || nil
      @options = options || QueryOperationOptions.new
    end

    def create_request(server_node)
      assert_node(server_node)
      query = @query
      options = @options

      if !query.is_a?(IndexQuery)
        raise RuntimeError, "Query must be instance of IndexQuery class"
      end

      if !options.is_a?(QueryOperationOptions)
        raise RuntimeError, "Options must be instance of QueryOperationOptions class"
      end

      @params = {
        "allowStale" => options.allow_stale,
        "details" => options.retrieve_details,
        "maxOpsPerSec" => options.max_ops_per_sec
      }

      @end_point = "/databases/#{server_node.database}/queries"
      
      if options.allow_stale && options.stale_timeout
        add_params("staleTimeout", options.stale_timeout)
      end  
    end
  end

  class RavenCommandData
    def initialize(id, change_vector)
      @id = id
      @change_vector = change_vector || nil
      @type = nil
    end

    def document_id
      @id
    end

    def to_json
      {
        "Type" => @type,
        "Id" => @id,
        "ChangeVector" => @change_vector
      }
    end
  end
end

require_relative './commands/batch'
require_relative './commands/databases'
require_relative './commands/documents'
require_relative './commands/indexes'
require_relative './commands/queries'
require_relative './commands/hilo'