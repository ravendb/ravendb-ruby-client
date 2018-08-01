RSpec.describe RavenDB::DocumentQuery, database: true do
  before do
    @lastfm = LastFmAnalyzed.new(store, self)

    @lastfm.execute
    ProductsTestingSort.new(store).execute

    store.open_session do |session|
      session.store(LastFm.new("LastFms/1", "Tania Maria", "TRALPJJ128F9311763", "Come With Me"))
      session.store(LastFm.new("LastFms/2", "Meghan Trainor", "TRBCNGI128F42597B4", "Me Too"))
      session.store(LastFm.new("LastFms/3", "Willie Bobo", "TRAACNS128F14A2DF5", "Spanish Grease"))
      session.store(Product.new("Products/101", "test101", 2, "a"))
      session.store(Product.new("Products/10", "test10", 3, "b"))
      session.store(Product.new("Products/106", "test106", 4, "c"))
      session.store(Product.new("Products/107", "test107", 5))
      session.store(Product.new("Products/103", "test107", 6))
      session.store(Product.new("Products/108", "new_testing", 90, "d"))
      session.store(Product.new("Products/110", "paginate_testing", 95))
      session.store(Order.new("Orders/105", "testing_order", 92, "Products/108"))
      session.store(Company.new("Companies/1", "withNesting", Product.new(nil, "testing_order", 4)))

      session.save_changes
    end
  end

  it "queries by single condition" do
    store.open_session do |session|
      results = session
                .query(collection: "Products")
                .where_equals("name", "test101")
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(1)
      expect(results.first.name).to eq("test101")
    end
  end

  it "queries by few conditions joined by or" do
    store.open_session do |session|
      results = session
                .query(collection: "Products")
                .where_equals("name", "test101")
                .where_equals("uid", 4)
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(2)
      expect((results.first.name.include?("test101") || results.last.name.include?("test101"))).to be_truthy
      expect(((results.first.uid == 2) || (results.last.uid == 2))).to be_truthy
    end
  end

  it "queries by few conditions joined by and" do
    store.open_session do |session|
      results = session
                .query(collection: "Products")
                .using_default_operator(RavenDB::QueryOperator::AND)
                .where_equals("name", "test107")
                .where_equals("uid", 5)
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(1)
      expect(results.first.name).to eq("test107")
      expect(results.first.uid).to eq(5)
    end
  end

  it "queries by where in" do
    names = ["test101", "test107", "test106"]

    store.open_session do |session|
      results = session
                .query(collection: "Products")
                .where_in("name", names)
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(4)

      results.each do |result|
        expect(names).to(be_any { |name| (result.name == name) })
      end
    end
  end

  it "queries by starts with" do
    store.open_session do |session|
      results = session
                .query(collection: "Products")
                .where_starts_with("name", "n")
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(1)
      expect(results.first.name).to eq("new_testing")
    end
  end

  it "queries by ends with" do
    store.open_session do |session|
      results = session
                .query(collection: "Products")
                .where_ends_with("name", "7")
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(2)
      expect(results).to(be_all { |result| result.name = "test107" })
    end
  end

  it "queries by between" do
    store.open_session do |session|
      results = session
                .query(collection: "Products")
                .where_between("uid", 2, 4)
                .wait_for_non_stale_results
                .all

      expect(results).to(be_all { |result| (2..4).to_a.include?(result.uid) })
      expect(results.size).to eq(3)
    end
  end

  it "queries by exists" do
    store.open_session do |session|
      results = session
                .query
                .where_exists("ordering")
                .wait_for_non_stale_results
                .all

      expect(results).to(be_all { |result| result.instance_variable_defined?("@ordering") })
    end
  end

  it "fails query by unexisting index" do
    store.open_session do |session|
      expect do
        session
          .query(index_name: "s")
          .wait_for_non_stale_results
          .all
      end.to raise_error(RavenDB::IndexDoesNotExistException)
    end
  end

  it "queries by index" do
    uids = [4, 6, 90]

    store.open_session do |session|
      results = session
                .query(index_name: "Testing_Sort", document_type: Product)
                .where_in("uid", uids)
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(3)

      results.each do |result|
        expect(uids).to(be_any { |uid| (result.uid == uid) })
      end
    end
  end

  it "queries with ordering" do
    store.open_session do |session|
      results = session
                .query
                .where_exists("ordering")
                .order_by("ordering")
                .wait_for_non_stale_results
                .all

      expect(results.first.ordering).to eq("a")
    end
  end

  it "queries with descending ordering" do
    store.open_session do |session|
      results = session
                .query
                .where_exists("ordering")
                .order_by_descending("ordering")
                .wait_for_non_stale_results
                .all

      expect(results.first.ordering).to eq("d")
    end
  end

  it "queries with includes" do
    store.open_session do |session|
      session.query(collection: "Orders")
             .where_equals("uid", 92)
             .include("product_id")
             .wait_for_non_stale_results
             .all

      session.load_new(Product, "Products/108")
      expect(session.number_of_requests_in_session).to eq(1)
    end
  end

  it "queries with nested objects" do
    store.open_session do |session|
      results = session
                .query(collection: "Companies")
                .where_equals("name", "withNesting")
                .wait_for_non_stale_results
                .all

      expect(results.first).to be_kind_of(Company)
      expect(results.first.product).to be_kind_of(Product)
    end
  end

  it "paginates" do
    expected_uids = [[2, 3], [4, 5], [6, 90], [95]]
    page_size = 2
    total_pages = nil

    store.open_session do |session|
      total_count = session
                    .query(collection: "Products")
                    .where_exists("uid")
                    .wait_for_non_stale_results
                    .count

      total_pages = (total_count.to_f / page_size).ceil

      expect(total_pages).to eq(4)
      expect(total_count).to eq(7)
    end

    (1..total_pages).to_a do |page|
      store.open_session do |session|
        products = session
                   .query(collection: "Products")
                   .where_exists("uid")
                   .order_by("uid")
                   .wait_for_non_stale_results
                   .skip(((page - 1) * page_size))
                   .take(page_size)
                   .all

        expect((products.size <= page_size)).to be_truthy
        products.each_index do |index|
          expect(expected_uids[(page - 1)][index]).to eq(products[index].uid)
        end
      end
    end
  end

  it "queries select fields" do
    store.open_session do |session|
      results = session
                .query(index_name: "Testing_Sort", document_type: Product)
                .select_fields(["doc_id"])
                .where_between("uid", 2, 4, true)
                .wait_for_non_stale_results
                .all

      expect(results).to(be_all { |result| result.instance_variable_defined?("@doc_id") })
    end
  end

  it "searches by single keyword" do
    store.open_session do |session|
      results = session
                .query(index_name: LastFmAnalyzed.name, document_type: LastFm)
                .search("query", "Me")
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(2)
      results.each do |last_fm|
        check_fulltext_search_result(last_fm, ["Me"])
      end
    end
  end

  it "searches by two keywords" do
    store.open_session do |session|
      results = session
                .query(index_name: LastFmAnalyzed.name, document_type: LastFm)
                .search("query", "Me Bobo")
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(3)

      results.each do |last_fm|
        check_fulltext_search_result(last_fm, ["Me", "Bobo"])
      end
    end
  end

  it "searches full text with boost" do
    store.open_session do |session|
      results = session
                .query(index_name: LastFmAnalyzed.name, document_type: LastFm)
                .search("query", "Me")
                .boost(10)
                .search("query", "Bobo")
                .boost(2)
                .wait_for_non_stale_results
                .all

      expect(results.size).to eq(3)
      expect(results.last.title).to eq("Spanish Grease")

      results.each do |last_fm|
        check_fulltext_search_result(last_fm, ["Me", "Bobo"])
      end
    end
  end

  def check_fulltext_search_result(last_fm, query)
    search_in = []
    fields = ["artist", "title"]

    fields.each do |field|
      query.each do |keyword|
        search_in.push(
          keyword: keyword,
          sample: last_fm.instance_variable_get("@#{field}")
        )
      end
    end

    expect(search_in).to(be_any { |comparsion| comparsion[:sample].include?(comparsion[:keyword]) })
  end
end
