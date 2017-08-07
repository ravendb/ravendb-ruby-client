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
    @_lastResponse = {};

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
      @_lastResponse = response.json

      if @_lastResponse
        ExceptionsRaiser.try_raise_from(response)
        return @_lastResponse
      end   
    end  

    protected
    def assert_node(node)
      raise ArgumentError, 'Argument "node" should be an instance of ServerNode' unless json.is_a? RavenDB::ServerNode
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
end