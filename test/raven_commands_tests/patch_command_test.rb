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

class PatchCommandTest < TestBase
  id = "products/10"
  @_change_vector = nil
  
  def setup
    super 

    @_request_executor.execute(PutDocumentCommand.new(id, {"Name" => "test", "@metadata" => {}}))
    result = @_request_executor.execute(GetDocumentCommand.new(id))
    @_change_vector = result.Results.first["@metadata"]["@change-vector"])
  end

  def should_patch_success_ignoring_missing
    result = store.operations.send(PatchOperation.new(id, PatchRequest.new("this.Name = 'testing'")))
    
    assert(result.key?("Document"))
    assert(result["Document"].is_a?(Hash))    
  end

  def should_patch_success_not_ignoring_missing
    result = store.operations.send(
      PatchOperation.new(id, PatchRequest.new("this.Name = 'testing'"), {
      "change_vector" => @_change_vector + 1, 
      "skip_patch_if_change_vector_mismatch" => true
    }))
    
    refute(result.key?("Document"))
  end

  def should_patch_fail_not_ignoring_missing
    assert_raises do
      result = store.operations.send(
        PatchOperation.new(id, PatchRequest.new("this.Name = 'testing'"), {
        "change_vector" => @_change_vector + 1, 
        "skip_patch_if_change_vector_mismatch" => false
      }))
    end
  end
end  