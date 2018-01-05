require 'ravendb'
require 'securerandom'
require 'minitest/autorun'
require 'spec_helper'

class IndexCommandsTest < RavenDatabaseTest
  def should_put_index_with_success
    @_index = RavenDB::IndexDefinition.new('region', @_index_map)

    refute_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
    end  
  end

  def test_should_get_index_with_success
    @_index = RavenDB::IndexDefinition.new('get_index', @_index_map)
    @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))

    result = @_store.operations.send(RavenDB::GetIndexOperation.new('get_index'))
    refute_nil(result)    
  end

  def test_should_get_index_with_fail
    assert_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::GetIndexOperation.new('non_existing_index'))
    end
  end

  def test_should_delete_index_with_success
    @_index = RavenDB::IndexDefinition.new('delete', @_index_map)
    @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))

    refute_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::DeleteIndexOperation.new('delete'))
    end

    assert_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::GetIndexOperation.new('delete'))
    end
  end

  def test_should_delete_index_with_fail
    assert_raises(RuntimeError) do
      @_store.operations.send(RavenDB::DeleteIndexOperation.new(nil))    
    end  
  end
end  