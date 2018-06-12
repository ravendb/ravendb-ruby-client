RSpec.describe RavenDB::PutDocumentCommand, database: true do
  it "puts successfully" do
    request_executor.execute(RavenDB::PutDocumentCommand.new(id: "Testings/1", document: {"name" => "test", "@metadata" => {:@id => "Testings/1", "@collection" => "testings"}}))
    command = RavenDB::GetDocumentCommand.new("Testings/1")
    request_executor.execute(command)
    result = command.result
    expect(result["Results"].first["@metadata"]["@id"]).to eq("Testings/1")
  end

  it "fails with invalid json" do
    expect do
      request_executor.execute(RavenDB::PutDocumentCommand.new(id: "testing/2", document: "invalid json"))
    end.to raise_error(RavenDB::RavenException)
  end
end
