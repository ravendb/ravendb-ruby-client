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

class PutCommandTest < TestBase  
  def should_put_successfully
    @_request_executor.execute(PutDocumentCommand.new('testing/1', {"name" => 'test', "@metadata" => {"@id" => 'testing/1', "@collection" => 'testings'}}))
    result = @_request_executor.execute(GetDocumentCommand.new('testing/1'))
    assert_equals('testing/1', result.Results.first['@metadata']['@id'])
  end

  def should_fail_with_invalid_json
    assert_raises do
      @_request_executor.execute(PutDocumentCommand.new('testing/2', 'invalid json'))
    end
  end
end  