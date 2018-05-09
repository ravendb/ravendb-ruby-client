RSpec.describe RavenDB::QueryCommand, database: true, database_indexes: true do
  before do
    query = "from index 'Testing' where Tag = 'Products'"

    document =  {
      "Name" => "test",
      "@metadata" => {
        "Raven-Ruby-Type": "Product",
        "@collection": "Products"
      }
    }
    request_executor.execute(RavenDB::PutDocumentCommand.new(id: "Products/10", document: document))

    @_conventions = store.conventions
    @_index_query = RavenDB::IndexQuery.new(query, {}, nil, nil, wait_for_non_stale_results: true)
  end

  it "does query" do
    result = request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query))

    expect(result["Results"].first).to include("Name")
    expect(result["Results"].first["Name"]).to eq("test")
  end

  it "test should query only metadata" do
    result = request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query, true, false))

    expect(result["Results"].first.key?("Name")).to eq(false)
  end

  it "queries only documents" do
    request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query))
    result = request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query, false, true))

    expect(result["Results"].first.key?("@metadata")).to eq(false)
  end

  it "fails with no existing index" do
    expect do
      @_index_query = RavenDB::IndexQuery.new("from index 'IndexIsNotExists' WHERE Tag = 'Products'", {}, nil, nil, wait_for_non_stale_results: true)
      request_executor.execute(RavenDB::QueryCommand.new(@_conventions, @_index_query))
    end.to raise_error(RavenDB::RavenException)
  end
end
