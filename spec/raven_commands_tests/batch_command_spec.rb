describe RavenDB::BatchCommand do
  before do
    @__test = RavenDatabaseIndexesTest.new(nil)
    @__test.setup

    metadata = {"Raven-Ruby-Type" => "Product", "@collection" => "Products"}

    @_put_command1 = RavenDB::PutCommandData.new("Products/999", "Name" => "tests", "Category" => "testing", "@metadata" => metadata)
    @_put_command2 = RavenDB::PutCommandData.new("Products/1000", "Name" => "tests", "Category" => "testing", "@metadata" => metadata)
    @_delete_command = RavenDB::DeleteCommandData.new("Products/1000")
    @_scripted_patch_command = RavenDB::PatchCommandData.new("Products/999", RavenDB::PatchRequest.new("this.Name = 'testing';"))
  end

  after do
    @__test.teardown
  end

  let(:request_executor) do
    @__test.request_executor
  end

  it "is success with one command" do
    result = request_executor.execute(described_class.new([@_put_command1]))
    expect(result.size).to eq(1)
  end

  it "is success with multi commands" do
    result = request_executor.execute(described_class.new([@_put_command1, @_put_command2, @_delete_command]))
    expect(result.size).to eq(3)
  end

  it "is success with a scripted patch" do
    request_executor.execute(described_class.new([@_put_command1, @_scripted_patch_command]))
    result = request_executor.execute(RavenDB::GetDocumentCommand.new("Products/999"))
    expect(result["Results"].first["Name"]).to eq("testing")
  end

  it "fails the test with invalid command data" do
    expect do
      request_executor.execute(described_class.new([@_put_command1, @_put_command2, nil]))
    end.to raise_error(RuntimeError)
  end
end
