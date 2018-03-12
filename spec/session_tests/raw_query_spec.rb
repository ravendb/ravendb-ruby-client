RSpec.describe RavenDB::RawDocumentQuery do
  before do
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    store.open_session do |session|
      session.store(Product.new("Products/101", "test101", 2, "a"))
      session.save_changes
    end
  end

  after do
    @__test.teardown
  end

  let(:store) do
    @__test.store
  end

  it "does raw query" do
    store.open_session do |session|
      results = session
                .advanced
                .raw_query("FROM Products WHERE name = $name", name: "test101")
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(1)
      expect(results.first.name).to eq("test101")
      expect(results.first.uid).to eq(2)
      expect(results.first.ordering).to eq("a")
    end
  end

  it "fails query with invalid rql" do
    store.open_session do |session|
      expect do
        session
          .advanced
          .raw_query("FROM Products WHERE")
          .wait_for_non_stale_results
          .all
      end.to raise_error(RavenDB::ParseException)
    end
  end
end
