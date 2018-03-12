class RavenDatabaseTest
  def initialize(parent)
    @parent = parent
  end

  def setup
    @parent.store.conventions.disable_topology_updates = false
    @_index_map =
      "from doc in docs "\
      "select new{"\
      "Tag = doc[\"@metadata\"][\"@collection\"],"\
      "LastModified = (DateTime)doc[\"@metadata\"][\"Last-Modified\"],"\
      "LastModifiedTicks = ((DateTime)doc[\"@metadata\"][\"Last-Modified\"]).Ticks}"

    db_doc = RavenDB::DatabaseDocument.new(@parent.current_database, 'Raven/DataDir': "test")
    store.maintenance.server.send(RavenDB::CreateDatabaseOperation.new(db_doc))
    @_request_executor = store.get_request_executor
  end

  def teardown
    @parent.store.maintenance.server.send(RavenDB::DeleteDatabaseOperation.new(@parent.current_database, true))
    @_request_executor = nil
    @_index_map = nil
  end

  def request_executor
    @_request_executor
  end

  def index_map
    @_index_map
  end

  def store
    @parent.store
  end
end

module RavenDatabaseTestHelpers
  def request_executor
    @__database_test.request_executor
  end

  def index_map
    @__database_test.index_map
  end
end
