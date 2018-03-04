require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

class QueryCommandTest < RavenDatabaseIndexesTest
  def setup
    super()

    query = "from index 'Testing' where Tag = 'Products'"

    @_request_executor.execute(RavenDB::PutDocumentCommand.new("Products/10", {
      "Name" => "test",
      "@metadata" => {
        "Raven-Ruby-Type": "Product",
        "@collection": "Products"
      }
    }))

    @_conventions = @_store.conventions
    @_index_query = RavenDB::IndexQuery.new(query, {}, nil, nil, {:wait_for_non_stale_results => true})
  end

  def test_should_do_query
    result = @_request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query))

    assert(result["Results"].first.key?("Name"))
    assert_equal("test", result["Results"].first["Name"])
  end

  def test_test_should_query_only_metadata
    result = @_request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query, true, false))

    refute(result["Results"].first.key?("Name"))
  end

  def test_should_query_only_documents
    @_request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query))
    result = @_request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query, false, true))

    refute(result["Results"].first.key?("@metadata"))
  end

  def test_should_fail_with_no_existing_index
    assert_raises(RavenDB::RavenException) do
      @_index_query = RavenDB::IndexQuery.new("from index 'IndexIsNotExists' WHERE Tag = 'Products'",  {}, nil, nil, {:wait_for_non_stale_results => true})
      @_request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query))
    end
  end
end