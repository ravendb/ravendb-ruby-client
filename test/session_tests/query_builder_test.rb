require "date"
require "ravendb"
require "spec_helper"

class QueryBuilderTest < Minitest::Test
  def setup
    @__test = RavenTest.new(nil)
    @__test.setup
  end

  def teardown
    @__test.teardown
  end

  def store
    @__test.store
  end

  def test_can_understand_equality
    query = store
            .open_session
            .query(collection: "Users")
            .where_equals("Name", "red")

    index_query = query.get_index_query

    assert_equal("FROM Users WHERE Name = $p0", index_query.query)
    assert_equal("red", index_query.query_parameters[:p0])
  end

  def test_can_understand_exact_equality
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Name", "ayende", true)

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE exact(Name = $p0)", index_query.query)
    assert_equal("ayende", index_query.query_parameters[:p0])
  end

  def test_can_understand_equal_on_date
    date_time = DateTime.strptime("2010-05-15T00:00:00", "%Y-%m-%dT%H:%M:%S")

    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Birthday", date_time)

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Birthday = $p0", index_query.query)
    assert_equal("2010-05-15T00:00:00.0000000", index_query.query_parameters[:p0])
  end

  def test_can_understand_equal_on_bool
    query = store
            .open_session
            .query(collection: "Users")
            .where_equals("Active", false)

    index_query = query.get_index_query

    assert_equal("FROM Users WHERE Active = $p0", index_query.query)
    assert_equal(false, index_query.query_parameters[:p0])
  end

  def test_can_understand_not_equal
    query = store
            .open_session
            .query(collection: "Users")
            .where_not_equals("Active", false)

    index_query = query.get_index_query

    assert_equal("FROM Users WHERE Active != $p0", index_query.query)
    assert_equal(false, index_query.query_parameters[:p0])
  end

  def test_can_understand_in
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_in("Name", ["ryan", "heath"])

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Name IN ($p0)", index_query.query)
    assert_equal(["ryan", "heath"], index_query.query_parameters[:p0])
  end

  def test_no_conditions_should_produce_empty_where
    query = store
            .open_session
            .query(index_name: "IndexName")

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName'", index_query.query)
  end

  def test_can_understand_and
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Name", "ayende")
            .and_also
            .where_equals("Email", "ayende@ayende.com")

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Name = $p0 AND Email = $p1", index_query.query)
    assert_equal("ayende", index_query.query_parameters[:p0])
    assert_equal("ayende@ayende.com", index_query.query_parameters[:p1])
  end

  def test_can_understand_or
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Name", "ayende")
            .or_else
            .where_equals("Email", "ayende@ayende.com")

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Name = $p0 OR Email = $p1", index_query.query)
    assert_equal("ayende", index_query.query_parameters[:p0])
    assert_equal("ayende@ayende.com", index_query.query_parameters[:p1])
  end

  def test_can_understand_less_than
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_less_than("Age", 16)

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Age < $p0", index_query.query)
    assert_equal(16, index_query.query_parameters[:p0])
  end

  def test_can_understand_less_than_or_equal
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_less_than_or_equal("Age", 16)

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Age <= $p0", index_query.query)
    assert_equal(16, index_query.query_parameters[:p0])
  end

  def test_can_understand_greater_than
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_greater_than("Age", 16)

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Age > $p0", index_query.query)
    assert_equal(16, index_query.query_parameters[:p0])
  end

  def test_can_understand_greater_than_or_equal
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_greater_than_or_equal("Age", 16)

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Age >= $p0", index_query.query)
    assert_equal(16, index_query.query_parameters[:p0])
  end

  def test_can_understand_projection_of_single_field
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_greater_than_or_equal("Age", 16)
            .select_fields(["Name"])

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Age >= $p0 SELECT Name", index_query.query)
    assert_equal(16, index_query.query_parameters[:p0])
  end

  def test_can_understand_projection_of_multiple_fields
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_greater_than_or_equal("Age", 16)
            .select_fields(["Name", "Age"])

    index_query = query.get_index_query

    assert_equal("FROM INDEX 'IndexName' WHERE Age >= $p0 SELECT Name, Age", index_query.query)
    assert_equal(16, index_query.query_parameters[:p0])
  end

  def test_can_understand_between
    min = 1224
    max = 1226

    query = store
            .open_session
            .query(collection: "IndexedUsers")
            .where_between("Rate", min, max)

    index_query = query.get_index_query

    assert_equal("FROM IndexedUsers WHERE Rate BETWEEN $p0 AND $p1", index_query.query)
    assert_equal(min, index_query.query_parameters[:p0])
    assert_equal(max, index_query.query_parameters[:p1])
  end

  def test_can_understand_starts_with
    query = store
            .open_session
            .query(collection: "Users")
            .where_starts_with("Name", "foo")

    index_query = query.get_index_query

    assert_equal("FROM Users WHERE startsWith(Name, $p0)", index_query.query)
    assert_equal("foo", index_query.query_parameters[:p0])
  end

  def test_can_understand_ends_with
    query = store
            .open_session
            .query(collection: "Users")
            .where_ends_with("Name", "foo")

    index_query = query.get_index_query

    assert_equal("FROM Users WHERE endsWith(Name, $p0)", index_query.query)
    assert_equal("foo", index_query.query_parameters[:p0])
  end

  def test_should_wrap_first_not_with_true_token
    query = store
            .open_session
            .query(collection: "Users")
            .where_true
            .and_also
            .not.where_starts_with("Name", "foo")

    index_query = query.get_index_query

    assert_equal("FROM Users WHERE true AND NOT startsWith(Name, $p0)", index_query.query)
    assert_equal("foo", index_query.query_parameters[:p0])
  end

  def test_can_understand_subclauses
    query = store
            .open_session
            .query(
              collection: "Users"
            )
            .where_greater_than_or_equal("Age", 16)
            .and_also
            .open_subclause
            .where_equals("Name", "rob")
            .or_else
            .where_equals("Name", "dave")
            .close_subclause

    index_query = query.get_index_query

    assert_equal("FROM Users WHERE Age >= $p0 AND (Name = $p1 OR Name = $p2)", index_query.query)
    assert_equal(16, index_query.query_parameters[:p0])
    assert_equal("rob", index_query.query_parameters[:p1])
    assert_equal("dave", index_query.query_parameters[:p2])
  end
end
