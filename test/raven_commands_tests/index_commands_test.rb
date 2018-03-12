require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

describe RavenDB::PutIndexesOperation do
  def setup
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup
  end

  def teardown
    @__test.teardown
  end

  def store
    @__test.store
  end

  def index_map
    @__test.index_map
  end

  def should_put_index_with_success
    @_index = RavenDB::IndexDefinition.new("region", index_map)

    refute_raises(RavenDB::RavenException) do
      store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
    end
  end

  def test_should_get_index_with_success
    @_index = RavenDB::IndexDefinition.new("get_index", index_map)
    store.operations.send(RavenDB::PutIndexesOperation.new(@_index))

    result = store.operations.send(RavenDB::GetIndexOperation.new("get_index"))
    refute_nil(result)
  end

  def test_should_get_index_with_fail
    assert_raises(RavenDB::RavenException) do
      store.operations.send(RavenDB::GetIndexOperation.new("non_existing_index"))
    end
  end

  def test_should_delete_index_with_success
    @_index = RavenDB::IndexDefinition.new("delete", index_map)
    store.operations.send(RavenDB::PutIndexesOperation.new(@_index))

    refute_raises(RavenDB::RavenException) do
      store.operations.send(RavenDB::DeleteIndexOperation.new("delete"))
    end

    assert_raises(RavenDB::RavenException) do
      store.operations.send(RavenDB::GetIndexOperation.new("delete"))
    end
  end

  def test_should_delete_index_with_fail
    assert_raises(RuntimeError) do
      store.operations.send(RavenDB::DeleteIndexOperation.new(nil))
    end
  end
end
