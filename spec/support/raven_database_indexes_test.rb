require_relative "./raven_database_test.rb"

class RavenDatabaseIndexesTest < RavenDatabaseTest
  def setup
    super

    @_index = RavenDB::IndexDefinition.new("Testing", @_index_map)
    @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
  end

  def teardown
    super
    @_index = nil
  end
end
