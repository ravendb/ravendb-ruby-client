RSpec.describe RavenDB::PutDocumentCommand, database: true do
  it "puts successfully" do
    request_executor.execute(described_class.new("Testings/1", "name" => "test", "@metadata" => {:@id => "Testings/1", "@collection" => "testings"}))
    result = request_executor.execute(RavenDB::GetDocumentCommand.new("Testings/1"))
    expect(result["Results"].first["@metadata"]["@id"]).to eq("Testings/1")
  end

  it "fails with invalid json" do
    expect do
      request_executor.execute(described_class.new("testing/2", "invalid json"))
    end.to raise_error(RavenDB::RavenException)
  end
end
