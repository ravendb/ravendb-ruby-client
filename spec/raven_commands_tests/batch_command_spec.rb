RSpec.describe RavenDB::BatchCommand, database: true, database_indexes: true do
  before do
    metadata = {"Raven-Ruby-Type" => "Product", "@collection" => "Products"}

    @_put_command1 = RavenDB::PutCommandData.new("Products/999", "Name" => "tests", "Category" => "testing", "@metadata" => metadata)
    @_put_command2 = RavenDB::PutCommandData.new("Products/1000", "Name" => "tests", "Category" => "testing", "@metadata" => metadata)
    @_delete_command = RavenDB::DeleteCommandData.new("Products/1000")
    @_scripted_patch_command = RavenDB::PatchCommandData.new("Products/999", RavenDB::PatchRequest.new("this.Name = 'testing';"))
  end

  it "is success with one command" do
    result = request_executor.execute(RavenDB::BatchCommand.new([@_put_command1]))
    expect(result.size).to eq(1)
  end

  it "is success with multi commands" do
    result = request_executor.execute(RavenDB::BatchCommand.new([@_put_command1, @_put_command2, @_delete_command]))
    expect(result.size).to eq(3)
  end

  it "is success with a scripted patch" do
    request_executor.execute(RavenDB::BatchCommand.new([@_put_command1, @_scripted_patch_command]))
    result = request_executor.execute(RavenDB::GetDocumentCommand.new("Products/999"))
    expect(result["Results"].first["Name"]).to eq("testing")
  end

  it "fails the test with invalid command data" do
    expect do
      request_executor.execute(RavenDB::BatchCommand.new([@_put_command1, @_put_command2, nil]))
    end.to raise_error(RuntimeError)
  end
end
