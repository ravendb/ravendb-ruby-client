RSpec.describe RavenDB::DeleteDocumentCommand, database: true do
  before do
    request_executor.execute(RavenDB::PutDocumentCommand.new(id: "Products/101", document: {"Name" => "test", "@metadata" => {}}))
    command = RavenDB::GetDocumentCommand.new("Products/101")
    request_executor.execute(command)
    response = command.result
    @_change_vector = response["Results"].first["@metadata"]["@change-vector"]

    request_executor.execute(RavenDB::PutDocumentCommand.new(id: "Products/102", document: {"Name" => "test", "@metadata" => {}}))
    command = RavenDB::GetDocumentCommand.new("Products/102")
    request_executor.execute(command)
    response = command.result
    @_other_change_vector = response["Results"].first["@metadata"]["@change-vector"]
  end

  it "deletes with no change vector" do
    command = RavenDB::DeleteDocumentCommand.new("Products/101")
    expect { request_executor.execute(command) }.not_to raise_error
  end

  it "deletes with change vector" do
    command = RavenDB::DeleteDocumentCommand.new("Products/102", @_other_change_vector)
    expect { request_executor.execute(command) }.not_to raise_error
  end

  it "fails delete if change vector mismatches" do
    expect do
      request_executor.execute(RavenDB::DeleteDocumentCommand.new("Products/101", "#{@_change_vector}:BROKEN:VECTOR"))
    end.to raise_error(RavenDB::RavenException)
  end
end
