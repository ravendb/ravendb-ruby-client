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
require 'constants/documents'
require 'spec_helper'

class PatchCommandTest < TestBase
  ID = "Products/10"
  @_change_vector = nil
  
  def setup
    super() 

    @_request_executor.execute(RavenDB::PutDocumentCommand.new(ID, {"Name" => "test", "@metadata" => {}}))
    result = @_request_executor.execute(RavenDB::GetDocumentCommand.new(ID))
    @_change_vector = result["Results"].first["@metadata"]["@change-vector"]
  end

  def test_should_patch_success_ignoring_missing
    result = @_store.operations.send(RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.Name = 'testing'")))
    documents = @_request_executor.execute(RavenDB::GetDocumentCommand.new(ID))

    assert(result.key?(:Status))
    assert(result.key?(:Document))
    assert_equal(result[:Status], RavenDB::PatchStatus::Patched)
    assert(result[:Document].is_a?(Hash))
    assert_equal('testing', documents["Results"].first["Name"])
  end

  def test_should_patch_success_not_ignoring_missing
    result = @_store.operations.send(
      RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.Name = 'testing'"), {
        :change_vector => "#{@_change_vector}_BROKEN_VECTOR",
        :skip_patch_if_change_vector_mismatch => true
    }))

    assert(result.key?(:Status))
    refute(result.key?(:Document))
    assert_equal(result[:Status], RavenDB::PatchStatus::NotModified)
  end

  def test_should_patch_fail_not_ignoring_missing
    assert_raises(RavenDB::RavenException) do
      @_store.operations.send(
        RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.Name = 'testing'"), {
          :change_vector => "#{@_change_vector}_BROKEN_VECTOR",
          :skip_patch_if_change_vector_mismatch => false
      }))
    end
  end
end  