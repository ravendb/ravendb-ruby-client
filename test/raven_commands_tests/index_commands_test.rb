require 'ravendb'
require 'securerandom'
require 'minitest/autorun'
require 'requests/request_executor'
require 'requests/request_helpers'
require 'documents/conventions'
require 'documents/document_query'
require 'database/operations'
require 'database/commands'
require 'spec_helper'

class IndexCommandsTest < TestBase  
  def should_put_index_with_success
    @_index = IndexDefinition.new('region', @_index_map)

    refute_raises do
      @_store.operations.send(PutIndexesOperation.new(@_index))
    end  
  end

  def should_get_index_with_success
    @_index = IndexDefinition.new('get_index', @_index_map)
    
    refute_raises do
      @_store.operations.send(PutIndexesOperation.new(@_index))
    end  

    result = @_store.operations.send(GetIndexOperation.new('get_index'))
    refute_empty(result)    
  end

  def should_get_index_with_fail
    assert_raises do
      @_store.operations.send(GetIndexOperation.new('non_existing_index'))
    end
  end

  def should_delete_index_with_success
    @_index = IndexDefinition.new('delete', @_index_map)

    @_store.operations.send(PutIndexesOperation.new(index))
    result = @_store.operations.send(DeleteIndexOperation.new('delete'))
    assert_empty(result)
  end

  def should_delete_index_with_fail
    assert_raises do
      @_store.operations.send(DeleteIndexOperation.new(nil))    
    end  
  end
end  