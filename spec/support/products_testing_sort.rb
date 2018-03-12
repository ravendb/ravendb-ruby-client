class ProductsTestingSort
  def initialize(store)
    index_map = "from doc in docs "\
      "select new {"\
      "name = doc.name,"\
      "uid = doc.uid,"\
      'doc_id = doc.uid+"_"+doc.name}'

    @store = store
    @index_definition = RavenDB::IndexDefinition.new(
      "Testing_Sort", index_map, nil,
      fields: {
        "doc_id" => RavenDB::IndexFieldOptions.new(nil, true)
      }
    )
  end

  def execute
    @store.operations.send(RavenDB::PutIndexesOperation.new(@index_definition))
  end
end
