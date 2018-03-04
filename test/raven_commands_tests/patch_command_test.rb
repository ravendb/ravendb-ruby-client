require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

class PatchCommandTest < RavenDatabaseIndexesTest
  ID = "Products/10"
  @_change_vector = nil

  def setup
    super()

    @_request_executor.execute(RavenDB::PutDocumentCommand.new(ID, {"name" => "test", "@metadata" => {"Raven-Ruby-Type" => "Product", "@collection" => "Products"}}))
    result = @_request_executor.execute(RavenDB::GetDocumentCommand.new(ID))
    @_change_vector = result["Results"].first["@metadata"]["@change-vector"]
  end

  def test_should_patch_success_ignoring_missing
    result = @_store.operations.send(RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.name = 'testing'")))

    assert(result.key?(:Status))
    assert(result.key?(:Document))
    assert_equal(result[:Status], RavenDB::PatchStatus::Patched)
    assert(result[:Document].is_a?(Product))
    assert_equal("testing", result[:Document].name)
  end

  def test_should_patch_success_not_ignoring_missing
    result = @_store.operations.send(
      RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.name = 'testing'"), {
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
        RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.name = 'testing'"), {
          :change_vector => "#{@_change_vector}_BROKEN_VECTOR",
          :skip_patch_if_change_vector_mismatch => false
      }))
    end
  end
end