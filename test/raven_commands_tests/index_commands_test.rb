require 'ravendb'
require 'securerandom'
require 'minitest/autorun'
require 'requests/request_executor'
require 'requests/request_helpers'
require 'documents/conventions'
require 'documents/document_query'
require 'database/operations'
require 'database/commands'
require 'database/exceptions'
require 'spec_helper'

class IndexCommandsTest < TestBase  
  def should_put_index_with_success
    @_index = RavenDB::IndexDefinition.new('region', @_index_map)

    refute_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
    end  
  end

  def should_get_index_with_success
    @_index = RavenDB::IndexDefinition.new('get_index', @_index_map)
    
    refute_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::PutIndexesOperation.new(@_index))
    end  

    result = @_store.operations.send(RavenDB::GetIndexOperation.new('get_index'))
    refute_empty(result)    
  end

  def should_get_index_with_fail
    assert_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::GetIndexOperation.new('non_existing_index'))
    end
  end

  def should_delete_index_with_success
    @_index = RavenDB::IndexDefinition.new('delete', @_index_map)

    @_store.operations.send(RavenDB::PutIndexesOperation.new(index))
    result = @_store.operations.send(RavenDB::DeleteIndexOperation.new('delete'))
    assert_empty(result)
  end

  def should_delete_index_with_fail
    assert_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::DeleteIndexOperation.new(nil))    
    end  
  end
end  