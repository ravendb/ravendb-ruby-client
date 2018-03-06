require "ravendb"
require "securerandom"
require "minitest/autorun"
require "spec_helper"

class BatchCommandTest < RavenDatabaseIndexesTest
  @_put_command1 = nil
  @_put_command2 = nil
  @_delete_command = nil
  @_scripted_patch_command = nil

  def setup
    metadata = {"Raven-Ruby-Type" => "Product", "@collection" => "Products"}
    super()

    @_put_command1 = RavenDB::PutCommandData.new("Products/999", "Name" => "tests", "Category" => "testing", "@metadata" => metadata)
    @_put_command2 = RavenDB::PutCommandData.new("Products/1000", "Name" => "tests", "Category" => "testing", "@metadata" => metadata)
    @_delete_command = RavenDB::DeleteCommandData.new("Products/1000")
    @_scripted_patch_command = RavenDB::PatchCommandData.new("Products/999", RavenDB::PatchRequest.new("this.Name = 'testing';"))
  end

  def test_should_be_success_with_one_command
    result = @_request_executor.execute(RavenDB::BatchCommand.new([@_put_command1]))
    assert_equal(1, result.size)
  end

  def test_should_be_success_with_multi_commands
    result = @_request_executor.execute(RavenDB::BatchCommand.new([@_put_command1, @_put_command2, @_delete_command]))
    assert_equal(3, result.size)
  end

  def test_should_be_success_with_a_scripted_patch
    @_request_executor.execute(RavenDB::BatchCommand.new([@_put_command1, @_scripted_patch_command]))
    result = @_request_executor.execute(RavenDB::GetDocumentCommand.new("Products/999"))
    assert_equal("testing", result["Results"].first["Name"])
  end

  def test_should_fail_the_test_with_invalid_command_data
    assert_raises(RuntimeError) do
      @_request_executor.execute(RavenDB::BatchCommand.new([@_put_command1, @_put_command2, nil]))
    end
  end
end
