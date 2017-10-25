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

class GetCommandTest < TestBase
  @_put_command = nil
  @_other_put_command = nil
  @_response = nil
  @_other_response = nil
  
  def setup
    super() 

    @_put_command = RavenDB::PutDocumentCommand.new('products/101', {"Name" => "test", "@metadata" => {}});
    @_other_put_command = RavenDB::PutDocumentCommand.new('products/10', {"Name" => "test", "@metadata" => {}});

    @_request_executor.execute(@_put_command)
    @_response = @_request_executor.execute(RavenDB::GetDocumentCommand.new('products/101'))

    @_request_executor.execute(@_other_put_command)
    @_other_response = @_request_executor.execute(RavenDB::GetDocumentCommand.new('products/10'))    
  end

  def test_document_id_should_be_equal_after_load
    assert_equal('products/101', @_response["Results"].first['@metadata']['@id'])
  end

  def test_different_document_ids_shouldnt_be_equals_after_load
    refute_equal(@_other_response["Results"].first['@metadata']['@id'], @_response["Results"].first['@metadata']['@id'])
  end

  def test_unexisting_document_loading_attempt_should_return_empty_response
    result = @_request_executor.execute(RavenDB::GetDocumentCommand.new('product'))
    assert_nil(result)
  end
end  