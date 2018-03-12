require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

describe RavenDB::GetDocumentCommand do
  @_put_command = nil
  @_other_put_command = nil
  @_response = nil
  @_other_response = nil

  def setup
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    @_put_command = RavenDB::PutDocumentCommand.new("Products/101", "Name" => "test", "@metadata" => {})
    @_other_put_command = RavenDB::PutDocumentCommand.new("Products/10", "Name" => "test", "@metadata" => {})

    request_executor.execute(@_put_command)
    @_response = request_executor.execute(RavenDB::GetDocumentCommand.new("Products/101"))

    request_executor.execute(@_other_put_command)
    @_other_response = request_executor.execute(RavenDB::GetDocumentCommand.new("Products/10"))
  end

  def teardown
    @__test.teardown
  end

  def request_executor
    @__test.request_executor
  end

  def test_document_id_should_be_equal_after_load
    assert_equal("Products/101", @_response["Results"].first["@metadata"]["@id"])
  end

  def test_different_document_ids_shouldnt_be_equals_after_load
    refute_equal(@_other_response["Results"].first["@metadata"]["@id"], @_response["Results"].first["@metadata"]["@id"])
  end

  def test_unexisting_document_loading_attempt_should_return_empty_response
    result = request_executor.execute(RavenDB::GetDocumentCommand.new("product"))
    assert_nil(result)
  end
end
