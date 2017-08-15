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

class ByIndexCommandsTest < TestBase
  @_patch = nil
  
  def setup
    super

    index_map = 
      "from doc in docs.Testings "\
      "select new{"\
      "Name = doc.Name,"\
      "DocNumber = doc.DocNumber} "

    index_sort = RavenDB::IndexDefinition.new('Testing_Sort', indexMap, nil, {
      "fields" => {
        "DocNumber" => RavenDB::IndexFieldOptions.new(SortOptions.Numeric)
      }
    })

    @_patch = RavenDB::PatchRequest.new("Name = 'Patched';")
    @_store.operations.send(RavenDB::PutIndexesOperation.new(indexSort))

    for i in 0..99 do
      @_request_executor.execute(RavenDB::PutDocumentCommand.new("testing/#{i}", {
        "Name" => "test#{i}", "DocNumber" => i,
        "@metadata": {"@collection" => "Testings"}
      }))
    end        
  end

  def update_by_index_success
    query = "from index 'Testing_Sort' where exists(Name)"
    index_query = RavenDB::IndexQuery.new(query, 0, 0, null, {"wait_for_non_stale_results" => true})
    query_command = RavenDB::QueryCommand.new(index_query, @_store.conventions)
    patch_by_index_operation = RavenDB::PatchByIndexOperation.new(RavenDB::IndexQuery.new(query), @_patch, RavenDB::QueryOperationOptions.new(false))
    
    @_request_executor.execute(query_command)
    response = @_store.operations.send(patch_by_index_operation)
    
    refute_nil(response)
    assert(response["Result"]["total"] >= 50)    
  end

  def delete_by_index_success
    query = "from index 'Testing_Sort' where DocNumber between 0 AND 49"
    index_query = RavenDB::IndexQuery.new(query, 0, 0, null, {"wait_for_non_stale_results" => true})
    query_command = RavenDB::QueryCommand.new(index_query, @_store.conventions)
    delete_by_index_operation = RavenDB::DeleteByIndexOperation.new(RavenDB::IndexQuery.new(query), RavenDB::QueryOperationOptions.new(false))
    @_request_executor.execute(query_command)
    response = @_store.operations.send(delete_by_index_operation)

    assert_equals('Completed', response["Status"])
  end 

  def update_by_index_fail_on_unexisting_index
    index_query = RavenDB::IndexQuery.new("from index 'unexisting_index_1' where Name = 'test1'")

    assert_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::PatchByIndexOperation.new(index_query, @_patch))
    end  
  end

  def delete_by_index_fail_on_unexisting_index
    index_query = RavenDB::IndexQuery.new("from index 'unexisting_index_2' where Name = 'test2'")

    assert_raises(RavenDB::RavenException) do
      @_store.operations.send(RavenDB::DeleteByIndexOperation.new(index_query))
    end  
  end   
end  