RSpec.describe RavenDB::PatchRequest, database: true, database_indexes: true, rdbc_171: true do
  ID = "Products/10".freeze

  before do
    document = {
      "name" => "test",
      "@metadata" => {
        "Raven-Ruby-Type" => "Product",
        "@collection" => "Products"
      }
    }
    request_executor.execute(RavenDB::PutDocumentCommand.new(id: ID, document: document))
    command = RavenDB::GetDocumentCommand.new(ID)
    request_executor.execute(command)
    result = command.result
    @_change_vector = result["Results"].first["@metadata"]["@change-vector"]
  end

  it "patches success ignoring missing" do
    result = store.operations.send(RavenDB::PatchOperation.new(id: ID, patch: RavenDB::PatchRequest.new("this.name = 'testing'")))

    expect(result).to include(:Status)
    expect(result).to include(:Document)
    expect(result[:Status]).to eq(RavenDB::PatchStatus::PATCHED)
    expect(result[:Document]).to be_kind_of(Product)
    expect(result[:Document].name).to eq("testing")
  end

  it "patches success not ignoring missing" do
    result = store.operations.send(
      RavenDB::PatchOperation.new(id: ID,
                                  patch: RavenDB::PatchRequest.new("this.name = 'testing'"),
                                  change_vector: "#{@_change_vector}_BROKEN_VECTOR",
                                  skip_patch_if_change_vector_mismatch: true
                                 ))

    expect(result).to include(:Status)
    expect(result).not_to include(:Document)
    expect(result[:Status]).to eq(RavenDB::PatchStatus::NOT_MODIFIED)
  end

  it "patches fail not ignoring missing" do
    expect do
      store.operations.send(
        RavenDB::PatchOperation.new(id: ID,
                                    patch: RavenDB::PatchRequest.new("this.name = 'testing'"),
                                    change_vector: "#{@_change_vector}_BROKEN_VECTOR",
                                    skip_patch_if_change_vector_mismatch: false
                                   ))
    end.to raise_error(RavenDB::RavenException)
  end
end
