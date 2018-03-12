describe RavenDB::GetDocumentCommand do
  before do
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    @_put_command = RavenDB::PutDocumentCommand.new("Products/101", "Name" => "test", "@metadata" => {})
    @_other_put_command = RavenDB::PutDocumentCommand.new("Products/10", "Name" => "test", "@metadata" => {})

    request_executor.execute(@_put_command)
    @_response = request_executor.execute(described_class.new("Products/101"))

    request_executor.execute(@_other_put_command)
    @_other_response = request_executor.execute(described_class.new("Products/10"))
  end

  after do
    @__test.teardown
  end

  let(:request_executor) do
    @__test.request_executor
  end

  it "document id should be equal after load" do
    expect(@_response["Results"].first["@metadata"]["@id"]).to eq("Products/101")
  end

  it "different document ids shouldnt be equals after load" do
    expect(@_response["Results"].first["@metadata"]["@id"]).not_to eq(@_other_response["Results"].first["@metadata"]["@id"])
  end

  it "unexisting document loading attempt should return empty response" do
    result = request_executor.execute(described_class.new("product"))
    expect(result).to be_nil
  end
end
