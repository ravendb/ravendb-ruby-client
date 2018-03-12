describe RavenDB::QueryCommand do
  before do
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    index_map =
      "from doc in docs.Testings "\
      "select new{"\
      "Name = doc.Name,"\
      "DocNumber = doc.DocNumber} "

    index_sort = RavenDB::IndexDefinition.new("Testing_Sort", index_map)
    store.operations.send(RavenDB::PutIndexesOperation.new(index_sort))

    (0..99).each do |i|
      request_executor.execute(RavenDB::PutDocumentCommand.new("Testings/#{i}",
                                                               "Name" => "test#{i}", "DocNumber" => i,
                                                               "@metadata": {"@collection" => "Testings"}))
    end

    request_executor.execute(described_class.new(store.conventions, RavenDB::IndexQuery.new("from index 'Testing_Sort'", {}, nil, nil, wait_for_non_stale_results: true)))
  end

  after do
    @__test.teardown
  end

  let(:store) do
    @__test.store
  end

  let(:request_executor) do
    @__test.request_executor
  end

  it "update by index success" do
    query = "from index 'Testing_Sort' where exists(Name) update { this.Name = args.name; }"
    index_query = RavenDB::IndexQuery.new(query, {name: "Patched"}, nil, nil, wait_for_non_stale_results: true)
    patch_by_index_operation = RavenDB::PatchByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))

    response = store.operations.send(patch_by_index_operation)

    expect(response).not_to be_nil
    expect(response["Result"]["Total"]).not_to be < 100

    query = "from index 'Testing_Sort' where Name = $name"
    index_query = RavenDB::IndexQuery.new(query, {name: "Patched"}, nil, nil, wait_for_non_stale_results: true)

    response = request_executor.execute(described_class.new(store.conventions, index_query))
    expect(response).to include("Results")
    expect(response["Results"]).to be_kind_of(Array)
    expect(response["Results"].length).not_to be < 100
  end

  it "update by index fail on unexisting index" do
    query = "from index 'unexisting_index_1' where Name = $name update { this.Name = args.newName; }"
    index_query = RavenDB::IndexQuery.new(query, {newName: "Patched"}, nil, nil, wait_for_non_stale_results: true)
    patch_by_index_operation = RavenDB::PatchByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))

    expect do
      store.operations.send(patch_by_index_operation)
    end.to raise_error(RavenDB::IndexDoesNotExistException)
  end

  it "delete by index success" do
    query = "from index 'Testing_Sort' where DocNumber between $min AND $max"
    index_query = RavenDB::IndexQuery.new(query, {min: 0, max: 49}, nil, nil, wait_for_non_stale_results: true)
    delete_by_index_operation = RavenDB::DeleteByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))

    response = store.operations.send(delete_by_index_operation)
    expect(response["Status"]).to eq("Completed")

    query_command = described_class.new(store.conventions, index_query)
    response = request_executor.execute(query_command)
    expect(response).to include("Results")
    expect(response["Results"]).to be_kind_of(Array)
    expect(response["Results"].length).to eq(0)
  end

  it "delete by index fail on unexisting index" do
    query = "from index 'unexisting_index_2' where Name = $name"
    index_query = RavenDB::IndexQuery.new(query, {name: "test1"}, nil, nil, wait_for_non_stale_results: true)
    delete_by_index_operation = RavenDB::DeleteByQueryOperation.new(index_query, RavenDB::QueryOperationOptions.new(false))

    expect do
      store.operations.send(delete_by_index_operation)
    end.to raise_error(RavenDB::IndexDoesNotExistException)
  end
end
