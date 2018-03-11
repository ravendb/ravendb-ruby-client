require("date")
require("ravendb")
require("spec_helper")

describe(RavenDB::QueryBuilder) do
  before do
    @__test = RavenTest.new(nil)
    @__test.setup
  end

  after do
    @__test.teardown
  end

  let(:store) do
    @__test.store
  end

  it "can understand equality" do
    query = store
            .open_session
            .query(collection: "Users")
            .where_equals("Name", "red")

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM Users WHERE Name = $p0"))
    expect(index_query.query_parameters[:p0]).to(eq("red"))
  end

  it "can understand exact equality" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Name", "ayende", true)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE exact(Name = $p0)"))
    expect(index_query.query_parameters[:p0]).to(eq("ayende"))
  end

  it "can understand equal on date" do
    date_time = DateTime.strptime("2010-05-15T00:00:00", "%Y-%m-%dT%H:%M:%S")

    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Birthday", date_time)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Birthday = $p0"))
    expect(index_query.query_parameters[:p0]).to(eq("2010-05-15T00:00:00.0000000"))
  end

  it "can understand equal on bool" do
    query = store
            .open_session
            .query(collection: "Users")
            .where_equals("Active", false)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM Users WHERE Active = $p0"))
    expect(index_query.query_parameters[:p0]).to(eq(false))
  end

  it "can understand not equal" do
    query = store
            .open_session
            .query(collection: "Users")
            .where_not_equals("Active", false)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM Users WHERE Active != $p0"))
    expect(index_query.query_parameters[:p0]).to(eq(false))
  end

  it "can understand in" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_in("Name", ["ryan", "heath"])

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Name IN ($p0)"))
    expect(index_query.query_parameters[:p0]).to(eq(["ryan", "heath"]))
  end

  it "no conditions should produce empty where" do
    query = store
            .open_session
            .query(index_name: "IndexName")

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName'"))
  end

  it "can understand and" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Name", "ayende")
            .and_also
            .where_equals("Email", "ayende@ayende.com")

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Name = $p0 AND Email = $p1"))
    expect(index_query.query_parameters[:p0]).to(eq("ayende"))
    expect(index_query.query_parameters[:p1]).to(eq("ayende@ayende.com"))
  end

  it "can understand or" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_equals("Name", "ayende")
            .or_else.where_equals("Email", "ayende@ayende.com")

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Name = $p0 OR Email = $p1"))
    expect(index_query.query_parameters[:p0]).to(eq("ayende"))
    expect(index_query.query_parameters[:p1]).to(eq("ayende@ayende.com"))
  end

  it "can understand less than" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_less_than("Age", 16)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Age < $p0"))
    expect(index_query.query_parameters[:p0]).to(eq(16))
  end

  it "can understand less than or equal" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_less_than_or_equal("Age", 16)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Age <= $p0"))
    expect(index_query.query_parameters[:p0]).to(eq(16))
  end

  it "can understand greater than" do
    query = store
            .open_session
            .query(index_name: "IndexName").where_greater_than("Age", 16)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Age > $p0"))
    expect(index_query.query_parameters[:p0]).to(eq(16))
  end

  it "can understand greater than or equal" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_greater_than_or_equal("Age", 16)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Age >= $p0"))
    expect(index_query.query_parameters[:p0]).to(eq(16))
  end

  it "can understand projection of single field" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_greater_than_or_equal("Age", 16)
            .select_fields(["Name"])

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Age >= $p0 SELECT Name"))
    expect(index_query.query_parameters[:p0]).to(eq(16))
  end

  it "can understand projection of multiple fields" do
    query = store
            .open_session
            .query(index_name: "IndexName")
            .where_greater_than_or_equal("Age", 16)
            .select_fields(["Name", "Age"])

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM INDEX 'IndexName' WHERE Age >= $p0 SELECT Name, Age"))
    expect(index_query.query_parameters[:p0]).to(eq(16))
  end

  it "can understand between" do
    min = 1224
    max = 1226

    query = store
            .open_session
            .query(collection: "IndexedUsers")
            .where_between("Rate", min, max)

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM IndexedUsers WHERE Rate BETWEEN $p0 AND $p1"))
    expect(index_query.query_parameters[:p0]).to(eq(min))
    expect(index_query.query_parameters[:p1]).to(eq(max))
  end

  it "can understand starts with" do
    query = store
            .open_session
            .query(collection: "Users").where_starts_with("Name", "foo")

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM Users WHERE startsWith(Name, $p0)"))
    expect(index_query.query_parameters[:p0]).to(eq("foo"))
  end

  it "can understand ends with" do
    query = store
            .open_session
            .query(collection: "Users")
            .where_ends_with("Name", "foo")

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM Users WHERE endsWith(Name, $p0)"))
    expect(index_query.query_parameters[:p0]).to(eq("foo"))
  end

  it "wraps first not with true token" do
    query = store
            .open_session
            .query(collection: "Users")
            .where_true
            .and_also
            .not.where_starts_with("Name", "foo")

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM Users WHERE true AND NOT startsWith(Name, $p0)"))
    expect(index_query.query_parameters[:p0]).to(eq("foo"))
  end

  it "can understand subclauses" do
    query = store
            .open_session
            .query(collection: "Users")
            .where_greater_than_or_equal("Age", 16)
            .and_also
            .open_subclause
            .where_equals("Name", "rob")
            .or_else
            .where_equals("Name", "dave")
            .close_subclause

    index_query = query.get_index_query

    expect(index_query.query).to(eq("FROM Users WHERE Age >= $p0 AND (Name = $p1 OR Name = $p2)"))
    expect(index_query.query_parameters[:p0]).to(eq(16))
    expect(index_query.query_parameters[:p1]).to(eq("rob"))
    expect(index_query.query_parameters[:p2]).to(eq("dave"))
  end
end
