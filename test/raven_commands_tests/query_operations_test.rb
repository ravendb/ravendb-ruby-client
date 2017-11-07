require 'ravendb'
require 'securerandom'
require 'minitest/autorun'
require 'spec_helper'

class QueryOperationsTest < TestBase
  def setup
    super()

    index_map = 
      "from doc in docs.Testings "\
      "select new{"\
      "Name = doc.Name,"\
      "DocNumber = doc.DocNumber} "

    index_sort = RavenDB::IndexDefinition.new('Testing_Sort', index_map)
    @_store.operations.send(RavenDB::PutIndexesOperation.new(index_sort))

    for i in 0..99 do
      @_request_executor.execute(RavenDB::PutDocumentCommand.new("Testings/#{i}", {
        "Name" => "test#{i}", "DocNumber" => i,
        "@metadata": {"@collection" => "Testings"}
      }))
    end

    @_request_executor.execute(RavenDB::QueryCommand.new(@_store.conventions, RavenDB::IndexQuery.new("from index 'Testing_Sort'", {}, nil, nil, {:wait_for_non_stale_results => true})))
  end

  def test_update_by_index_success
    query = "from index 'Testing_Sort' where exists(Name) update { this.Name = args.name; }"
    index_query = RavenDB::IndexQuery.new(query, {:name => 'Patched'}, nil, nil, {:wait_for_non_stale_results => true})
    patch_by_index_operation = RavenDB::PatchByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))
    
    response = @_store.operations.send(patch_by_index_operation)
    
    refute_nil(response)
    refute(response["Result"]["Total"] < 100)

    query = "from index 'Testing_Sort' where Name = $name"
    index_query = RavenDB::IndexQuery.new(query, {:name => 'Patched'}, nil, nil, {:wait_for_non_stale_results => true})

    response = @_request_executor.execute(RavenDB::QueryCommand.new(@_store.conventions, index_query))
    assert(response.key?("Results"))
    assert(response["Results"].is_a?(Array))
    refute(response["Results"].length < 100)
  end

  def test_update_by_index_fail_on_unexisting_index
    query = "from index 'unexisting_index_1' where Name = $name update { this.Name = args.newName; }"
    index_query = RavenDB::IndexQuery.new(query, {:newName => "Patched"}, nil, nil, {:wait_for_non_stale_results => true})
    patch_by_index_operation = RavenDB::PatchByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))

    assert_raises(RavenDB::IndexDoesNotExistException) do
      @_store.operations.send(patch_by_index_operation)
    end
  end

  def test_delete_by_index_success
    query = "from index 'Testing_Sort' where DocNumber between $min AND $max"
    index_query = RavenDB::IndexQuery.new(query, {:min => 0, :max => 49}, nil, nil, {:wait_for_non_stale_results => true})
    delete_by_index_operation = RavenDB::DeleteByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))

    response = @_store.operations.send(delete_by_index_operation)
    assert_equal('Completed', response["Status"])

    query_command = RavenDB::QueryCommand.new(@_store.conventions, index_query)
    response = @_request_executor.execute(query_command)
    assert(response.key?("Results"))
    assert(response["Results"].is_a?(Array))
    assert_equal(response["Results"].length, 0)
  end

  def test_delete_by_index_fail_on_unexisting_index
    query = "from index 'unexisting_index_2' where Name = $name"
    index_query = RavenDB::IndexQuery.new(query, {:name => 'test1'}, nil, nil, {:wait_for_non_stale_results => true})
    delete_by_index_operation = RavenDB::DeleteByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))

    assert_raises(RavenDB::IndexDoesNotExistException) do
      @_store.operations.send(delete_by_index_operation)
    end  
  end   
end  