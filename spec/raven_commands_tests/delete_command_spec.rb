describe RavenDB::DeleteDocumentCommand do
  @_change_vector = nil
  @_other_change_vector = nil

  before do
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    request_executor.execute(RavenDB::PutDocumentCommand.new("Products/101", "Name" => "test", "@metadata" => {}))
    response = request_executor.execute(RavenDB::GetDocumentCommand.new("Products/101"))
    @_change_vector = response["Results"].first["@metadata"]["@change-vector"]

    request_executor.execute(RavenDB::PutDocumentCommand.new("Products/102", "Name" => "test", "@metadata" => {}))
    response = request_executor.execute(RavenDB::GetDocumentCommand.new("Products/102"))
    @_other_change_vector = response["Results"].first["@metadata"]["@change-vector"]
  end

  after do
    @__test.teardown
  end

  let(:request_executor) do
    @__test.request_executor
  end

  it "deletes with no change vector" do
    command = described_class.new("Products/101")
    expect { request_executor.execute(command) }.not_to raise_error
  end

  it "deletes with change vector" do
    command = described_class.new("Products/102", @_other_change_vector)
    expect { request_executor.execute(command) }.not_to raise_error
  end

  it "fails delete if change vector mismatches" do
    expect do
      request_executor.execute(described_class.new("Products/101", "#{@_change_vector}:BROKEN:VECTOR"))
    end.to raise_error(RavenDB::RavenException)
  end
end
