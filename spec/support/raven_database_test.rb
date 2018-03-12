require_relative "./raven_test.rb"

class RavenDatabaseTest < RavenTest
  def setup
    super
    @_store.conventions.disable_topology_updates = false
    @_index_map =
      "from doc in docs "\
      "select new{"\
      "Tag = doc[\"@metadata\"][\"@collection\"],"\
      "LastModified = (DateTime)doc[\"@metadata\"][\"Last-Modified\"],"\
      "LastModifiedTicks = ((DateTime)doc[\"@metadata\"][\"Last-Modified\"]).Ticks}"

    db_doc = RavenDB::DatabaseDocument.new(@_current_database, 'Raven/DataDir': "test")
    @_store.maintenance.server.send(RavenDB::CreateDatabaseOperation.new(db_doc))
    @_request_executor = @_store.get_request_executor
  end

  def teardown
    @_store.maintenance.server.send(RavenDB::DeleteDatabaseOperation.new(@_current_database, true))
    @_request_executor = nil
    @_index_map = nil
    super
  end

  def request_executor
    @_request_executor
  end

  def index_map
    @_index_map
  end
end
