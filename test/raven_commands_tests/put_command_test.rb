require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

describe RavenDB::PutDocumentCommand do
  def setup
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup
  end

  def teardown
    @__test.teardown
  end

  def request_executor
    @__test.request_executor
  end

  def test_should_put_successfully
    request_executor.execute(RavenDB::PutDocumentCommand.new("Testings/1", "name" => "test", "@metadata" => {"@id": "Testings/1", "@collection" => "testings"}))
    result = request_executor.execute(RavenDB::GetDocumentCommand.new("Testings/1"))
    assert_equal("Testings/1", result["Results"].first["@metadata"]["@id"])
  end

  def test_should_fail_with_invalid_json
    assert_raises(RavenDB::RavenException) do
      request_executor.execute(RavenDB::PutDocumentCommand.new("testing/2", "invalid json"))
    end
  end
end
