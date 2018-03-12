module RavenDatabaseTest
  def self.setup(context)
    context.instance_eval do
      store.conventions.disable_topology_updates = false
      @_index_map =
        "from doc in docs "\
        "select new{"\
        "Tag = doc[\"@metadata\"][\"@collection\"],"\
        "LastModified = (DateTime)doc[\"@metadata\"][\"Last-Modified\"],"\
        "LastModifiedTicks = ((DateTime)doc[\"@metadata\"][\"Last-Modified\"]).Ticks}"

      db_doc = RavenDB::DatabaseDocument.new(current_database, 'Raven/DataDir': "test")
      store.maintenance.server.send(RavenDB::CreateDatabaseOperation.new(db_doc))
      @_request_executor = store.get_request_executor
    end
  end

  def self.teardown(context)
    context.instance_eval do
      store.maintenance.server.send(RavenDB::DeleteDatabaseOperation.new(current_database, true))
      @_request_executor = nil
      @_index_map = nil
    end
  end
end

module RavenDatabaseTestHelpers
  def request_executor
    @_request_executor
  end

  def index_map
    @_index_map
  end
end
