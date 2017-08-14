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
    index_query = RavenDB::IndexQuery.new('FROM @all_docs WHERE NOT Name = NULL', 0, 0, null, {"wait_for_non_stale_results" => true})
    query_command = RavenDB::QueryCommand.new('Testing_Sort', index_query, @_store.conventions)
    patch_by_index_operation = RavenDB::PatchByIndexOperation.new('Testing_Sort', RavenDB::IndexQuery.new('FROM @all_docs'), @_patch, RavenDB::QueryOperationOptions.new(false))
    
    @_request_executor.execute(query_command)
    response = @_store.operations.send(patch_by_index_operation)
    
    refute_nil(response)
    assert(response["Result"]["total"] >= 50)    
  end

  def update_by_index_fail
    assert_raises do
      @_store.operations.send(RavenDB::PatchByIndexOperation.new('', RavenDB::IndexQuery.new('FROM @all_docs WHERE Name = "test"'), @_patch))
    end  
  end

  def delete_by_index_fail
    assert_raises do
      @_store.operations.send(RavenDB::DeleteByIndexOperation.new('region2', RavenDB::IndexQuery.new('FROM @all_docs WHERE Name = "Western"')))
    end  
  end

  def delete_by_index_success
    query = 'FROM @all_docs WHERE DocNumber BETWEEN 0 AND 49'
    index_query = RavenDB::IndexQuery.new(query, 0, 0, null, {"wait_for_non_stale_results" => true})
    query_command = RavenDB::QueryCommand.new('Testing_Sort', index_query, @_store.conventions)
    delete_by_index_operation = RavenDB::DeleteByIndexOperation.new('Testing_Sort', RavenDB::IndexQuery.new(query), RavenDB::QueryOperationOptions.new(false))

    @_request_executor.execute(query_command)
    response = @_store.operations.send(delete_by_index_operation)

    assert_equals('Completed', response["Status"])
  end  
end  