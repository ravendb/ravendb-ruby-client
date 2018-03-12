require "date"
require "ravendb"
require "spec_helper"

describe RavenDB::RawDocumentQuery do
  def setup
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    store.open_session do |session|
      session.store(Product.new("Products/101", "test101", 2, "a"))
      session.save_changes
    end
  end

  def teardown
    @__test.teardown
  end

  def store
    @__test.store
  end

  def test_should_do_raw_query
    store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE name = $name",
        name: "test101"
      )
                       .wait_for_non_stale_results
                       .all

      assert_equal(1, results.size)
      assert_equal("test101", results.first.name)
      assert_equal(2, results.first.uid)
      assert_equal("a", results.first.ordering)
    end
  end

  def test_should_fail_query_with_invalid_rql
    store.open_session do |session|
      assert_raises(RavenDB::ParseException) do
        session.advanced
               .raw_query("FROM Products WHERE")
               .wait_for_non_stale_results
               .all
      end
    end
  end
end
