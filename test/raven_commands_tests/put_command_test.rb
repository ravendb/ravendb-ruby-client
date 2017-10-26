require 'ravendb'
require 'securerandom'
require 'minitest/autorun'
require 'requests/request_executor'
require 'requests/request_helpers'
require 'documents/conventions'
require 'documents/document_query'
require "documents/indexes"
require 'database/operations'
require 'database/commands'
require 'database/exceptions'
require 'spec_helper'

class PutCommandTest < TestBase  
  def test_should_put_successfully
    @_request_executor.execute(RavenDB::PutDocumentCommand.new('Testings/1', {"name" => 'test', "@metadata" => {"@id": "Testings/1", "@collection" => 'testings'}}))
    result = @_request_executor.execute(RavenDB::GetDocumentCommand.new('Testings/1'))
    assert_equal('Testings/1', result["Results"].first["@metadata"]["@id"])
  end

  def test_should_fail_with_invalid_json
    assert_raises(RavenDB::RavenException) do
      @_request_executor.execute(RavenDB::PutDocumentCommand.new('testing/2', 'invalid json'))
    end
  end
end  