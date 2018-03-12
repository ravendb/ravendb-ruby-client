RSpec.describe RavenDB::PutIndexesOperation, database: true do
  it "puts index with success" do
    @_index = RavenDB::IndexDefinition.new("region", index_map)

    expect do
      store.operations.send(described_class.new(@_index))
    end.not_to raise_error
  end

  it "gets index with success" do
    @_index = RavenDB::IndexDefinition.new("get_index", index_map)
    store.operations.send(described_class.new(@_index))

    result = store.operations.send(RavenDB::GetIndexOperation.new("get_index"))
    expect(result).not_to be_nil
  end

  it "gets index with fail" do
    expect do
      store.operations.send(RavenDB::GetIndexOperation.new("non_existing_index"))
    end.to raise_error(RavenDB::RavenException)
  end

  it "deletes index with success" do
    @_index = RavenDB::IndexDefinition.new("delete", index_map)
    store.operations.send(described_class.new(@_index))

    expect do
      store.operations.send(RavenDB::DeleteIndexOperation.new("delete"))
    end.not_to raise_error

    expect do
      store.operations.send(RavenDB::GetIndexOperation.new("delete"))
    end.to raise_error(RavenDB::RavenException)
  end

  it "deletes index with fail" do
    expect do
      store.operations.send(RavenDB::DeleteIndexOperation.new(nil))
    end.to raise_error(RuntimeError)
  end
end
