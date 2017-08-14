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

class DeleteCommandTest < TestBase
  @_change_vector = nil
  @_other_change_vector = nil  
  
  def setup
    super 

    @_request_executor.execute(RavenDB::PutDocumentCommand.new('products/101', {"Name" => "test", "@metadata" => {}}))
    response = @_request_executor.execute(RavenDB::GetDocumentCommand.new('products/101'))
    @_change_vector = response.Results.first['@metadata']['@change-vector']

    @_request_executor.execute(RavenDB::PutDocumentCommand.new('products/102', {"Name" => "test", "@metadata" => {}}))
    response = @_request_executor.execute(RavenDB::GetDocumentCommand.new('products/102'))
    @_other_change_vector = response.Results.first['@metadata']['@change-vector']
  end

  def should_delete_with_no_change_vector
    command = RavenDB::DeleteDocumentCommand.new('products/101')

    refute_raises do 
      @_request_executor.execute(command)
    end  
  end

  def should_delete_with_change_vector
    command = RavenDB::DeleteDocumentCommand.new('products/102', @_other_change_vector)
    
    refute_raises do 
      @_request_executor.execute(command)
    end  
  end

  def should_fail_delete_if_change_vector_mismatches
    refute_raises do 
      @_request_executor.execute(RavenDB::DeleteDocumentCommand.new('products/101', "#{@_change_vector}:BROKEN:VECTOR"))
    end
  end 
end  