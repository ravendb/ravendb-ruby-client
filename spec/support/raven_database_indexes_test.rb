class RavenDatabaseIndexesTest
  def initialize(parent)
    @parent = parent
  end

  def setup
    @_index = RavenDB::IndexDefinition.new("Testing", @parent.index_map)
    @parent.store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
  end

  def teardown
    @_index = nil
  end
end
