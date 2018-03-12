require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

describe RavenDB::PatchRequest do
  ID = "Products/10".freeze
  @_change_vector = nil

  def setup
    @__test = RavenDatabaseIndexesTest.new(nil)
    @__test.setup

    request_executor.execute(RavenDB::PutDocumentCommand.new(ID, "name" => "test", "@metadata" => {"Raven-Ruby-Type" => "Product", "@collection" => "Products"}))
    result = request_executor.execute(RavenDB::GetDocumentCommand.new(ID))
    @_change_vector = result["Results"].first["@metadata"]["@change-vector"]
  end

  def teardown
    @__test.teardown
  end

  def store
    @__test.store
  end

  def request_executor
    @__test.request_executor
  end

  def test_should_patch_success_ignoring_missing
    result = store.operations.send(RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.name = 'testing'")))

    assert(result.key?(:Status))
    assert(result.key?(:Document))
    assert_equal(result[:Status], RavenDB::PatchStatus::Patched)
    assert(result[:Document].is_a?(Product))
    assert_equal("testing", result[:Document].name)
  end

  def test_should_patch_success_not_ignoring_missing
    result = store.operations.send(
      RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.name = 'testing'"),
                                  change_vector: "#{@_change_vector}_BROKEN_VECTOR",
                                  skip_patch_if_change_vector_mismatch: true
                                 ))

    assert(result.key?(:Status))
    refute(result.key?(:Document))
    assert_equal(result[:Status], RavenDB::PatchStatus::NotModified)
  end

  def test_should_patch_fail_not_ignoring_missing
    assert_raises(RavenDB::RavenException) do
      store.operations.send(
        RavenDB::PatchOperation.new(ID, RavenDB::PatchRequest.new("this.name = 'testing'"),
                                    change_vector: "#{@_change_vector}_BROKEN_VECTOR",
                                    skip_patch_if_change_vector_mismatch: false
                                   ))
    end
  end
end
