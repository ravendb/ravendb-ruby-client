require 'observer'
require 'constants/database'
require 'constants/documents'
require 'database/exceptions'
require 'database/commands'
require 'documents/conventions'
require 'request/request_helpers'

class RequestExecutor
  MaxFirstTopologyUpdatesTries = 5
  
  include Observable

  @headers = {}
  @_first_topology_updates_tries = 0
  @_first_topology_update = nil
  @_without_topology = false
  @_node_selector = nil
  @_last_known_urls = nil
  @_initial_database = nil
  @_topology_etag = 0
  @_failded_nodes_statuses = {}

  def initial_database
    @_initialDatabase
  end

  def self.create(urls, database = nil)
    return self.new(database, {
      "without_topology" => false,
      "first_topology_update_urls" => urls.clone
    })
  end

  def self.create_for_single_node(url, database = nil)
    topology = Topology.new(-1, [ServerNode.new(url, database)])

    return self.new(database, {
      "without_topology" => true,
      "single_node_topology" => topology,
      "topology_etag" => -2
    })
  end

  def initialize(database, options = {})
    urls = options["first_topology_update_urls"] || []

    @headers = {
      "Accept" => "application/json",
      "Raven-Client-Version" => "4.0.0-beta",
    }

    @_last_known_urls = null
    @_initial_database = database
    @_without_topology = options["without_topology"] || false
    @_topology_etag = options["topology_etag"] || 0    

    if !@_withoutTopology && !urls.empty?
      start_first_topology_update(urls)
    elsif (@_withoutTopology && options["single_node_topology"]) {
      @_node_selector = NodeSelector.new(self, options["single_node_topology"])
    end
  end

  protected
  def start_first_topology_update(urls)
    @_last_known_urls = urls
  end  

  protected
  def get_update_topology_command_class
    return GetTopologyCommand.class
  end  
end  

class ClusterRequestExecutor < RequestExecutor
  protected
  def get_update_topology_command_class
    return GetClusterTopologyCommand.class
  end  
end