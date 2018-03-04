require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

class DeleteCommandTest < RavenDatabaseTest
  @_change_vector = nil
  @_other_change_vector = nil

  def setup
    super()

    @_request_executor.execute(RavenDB::PutDocumentCommand.new("Products/101", "Name" => "test", "@metadata" => {}))
    response = @_request_executor.execute(RavenDB::GetDocumentCommand.new("Products/101"))
    @_change_vector = response["Results"].first["@metadata"]["@change-vector"]

    @_request_executor.execute(RavenDB::PutDocumentCommand.new("Products/102", "Name" => "test", "@metadata" => {}))
    response = @_request_executor.execute(RavenDB::GetDocumentCommand.new("Products/102"))
    @_other_change_vector = response["Results"].first["@metadata"]["@change-vector"]
  end

  def test_should_delete_with_no_change_vector
    command = RavenDB::DeleteDocumentCommand.new("Products/101")

    refute_raises(RavenDB::RavenException) do
      @_request_executor.execute(command)
    end
  end

  def test_should_delete_with_change_vector
    command = RavenDB::DeleteDocumentCommand.new("Products/102", @_other_change_vector)

    refute_raises(RavenDB::RavenException) do
      @_request_executor.execute(command)
    end
  end

  def test_should_fail_delete_if_change_vector_mismatches
    assert_raises(RavenDB::RavenException) do
      @_request_executor.execute(RavenDB::DeleteDocumentCommand.new("Products/101", "#{@_change_vector}:BROKEN:VECTOR"))
    end
  end
end