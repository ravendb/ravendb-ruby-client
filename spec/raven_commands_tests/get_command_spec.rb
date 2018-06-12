RSpec.describe RavenDB::GetDocumentCommand, database: true do
  before do
    @_put_command = RavenDB::PutDocumentCommand.new(id: "Products/101", document: {"Name" => "test", "@metadata" => {}})
    @_other_put_command = RavenDB::PutDocumentCommand.new(id: "Products/10", document: {"Name" => "test", "@metadata" => {}})

    request_executor.execute(@_put_command)
    command = RavenDB::GetDocumentCommand.new("Products/101")
    request_executor.execute(command)
    @_response = command.result

    request_executor.execute(@_other_put_command)
    command = RavenDB::GetDocumentCommand.new("Products/10")
    request_executor.execute(command)
    @_other_response = command.result
  end

  it "document id should be equal after load" do
    expect(@_response["Results"].first["@metadata"]["@id"]).to eq("Products/101")
  end

  it "different document ids shouldnt be equals after load" do
    expect(@_response["Results"].first["@metadata"]["@id"]).not_to eq(@_other_response["Results"].first["@metadata"]["@id"])
  end

  it "unexisting document loading attempt should return empty response" do
    command = RavenDB::GetDocumentCommand.new("product")
    request_executor.execute(command)
    result = command.result
    expect(result).to be_nil
  end
end
