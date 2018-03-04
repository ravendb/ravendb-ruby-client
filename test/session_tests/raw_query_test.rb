require "date"
require "ravendb"
require "spec_helper"

class RawQueryTest < RavenDatabaseTest
  def setup
    super
    @_store.open_session do |session|
      session.store(Product.new("Products/101", "test101", 2, "a"))
      session.save_changes
    end
  end

  def test_should_do_raw_query
    @_store.open_session do |session|
      results = session.advanced.raw_query(
        "FROM Products "\
        "WHERE name = $name", {
        :name => "test101"
      })
      .wait_for_non_stale_results
      .all

      assert_equal(results.size, 1)
      assert_equal(results.first.name, "test101")
      assert_equal(results.first.uid, 2)
      assert_equal(results.first.ordering, "a")
    end
  end

  def test_should_fail_query_with_invalid_rql
    @_store.open_session do |session|
      assert_raises(RavenDB::ParseException) do
        session.advanced
            .raw_query("FROM Products WHERE")
            .wait_for_non_stale_results
            .all
      end
    end
  end
end