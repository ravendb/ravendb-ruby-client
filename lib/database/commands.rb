require 'set'
require 'net/http'
require 'requests/request_helpers'

module RavenDB
  class RavenCommand
    @method = Net::HTTP::Get::METHOD
    @end_point = ""
    @params = {}
    @payload = {}
    @headers = {}
    @failed_nodes = nil;
    @_lastResponse = {};

    def initialize(end_point: string, method = Net::HTTP::Get::METHOD, params = nil, payload = nil, headers = {})
      @endPoint = end_point;
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
      raise ArgumentError, 'Argument "node" should be an instance of ServerNode' unless json.is_a? RavenDB::ServerNode
      @failed_nodes.add(node);
    end
  
    def was_failed_with_node(node)
      raise ArgumentError, 'Argument "node" should be an instance of ServerNode' unless json.is_a? RavenDB::ServerNode
      return @failed_nodes.include?(node);
    end
  end  
end