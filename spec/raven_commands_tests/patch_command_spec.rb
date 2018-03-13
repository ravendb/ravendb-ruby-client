RSpec.describe RavenDB::PatchRequest, database: true, database_indexes: true do
  ID = "Products/10".freeze

  before do
    request_executor.execute(RavenDB::PutDocumentCommand.new(ID, "name" => "test", "@metadata" => {"Raven-Ruby-Type" => "Product", "@collection" => "Products"}))
    result = request_executor.execute(RavenDB::GetDocumentCommand.new(ID))
    @_change_vector = result["Results"].first["@metadata"]["@change-vector"]
  end

  it "patches success ignoring missing" do
    result = store.operations.send(RavenDB::PatchOperation.new(ID, described_class.new("this.name = 'testing'")))

    expect(result).to include(:Status)
    expect(result).to include(:Document)
    expect(result[:Status]).to eq(RavenDB::PatchStatus::Patched)
    expect(result[:Document]).to be_kind_of(Product)
    expect(result[:Document].name).to eq("testing")
  end

  it "patches success not ignoring missing" do
    result = store.operations.send(
      RavenDB::PatchOperation.new(ID, described_class.new("this.name = 'testing'"),
                                  change_vector: "#{@_change_vector}_BROKEN_VECTOR",
                                  skip_patch_if_change_vector_mismatch: true
                                 ))

    expect(result).to include(:Status)
    expect(result).not_to include(:Document)
    expect(result[:Status]).to eq(RavenDB::PatchStatus::NotModified)
  end

  it "patches fail not ignoring missing" do
    expect do
      store.operations.send(
        RavenDB::PatchOperation.new(ID, described_class.new("this.name = 'testing'"),
                                    change_vector: "#{@_change_vector}_BROKEN_VECTOR",
                                    skip_patch_if_change_vector_mismatch: false
                                   ))
    end.to raise_error(RavenDB::RavenException)
  end
end
