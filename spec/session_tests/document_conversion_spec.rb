require "date"
require "ravendb"
require "spec_helper"

describe RavenDB::DocumentConventions do
  NOW = DateTime.now

  before do
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    store.open_session do |session|
      session.store(make_document("TestConversions/1"))
      session.store(make_document("TestConversions/2", NOW.next_day))
      session.save_changes
    end
  end

  after do
    @__test.teardown
  end

  let(:store) do
    @__test.store
  end

  it "converts on load" do
    id = "TestConversions/1"

    store.open_session do |session|
      doc = session.load(id)
      check_doc(id, doc)
    end
  end

  it "converts on store then reload" do
    id = "TestConversions/New"

    store.open_session do |session|
      session.store(make_document(id))
      session.save_changes
    end

    store.open_session do |session|
      doc = session.load(id)
      check_doc(id, doc)
    end
  end

  it "converts on query" do
    store.open_session do |session|
      results = session
                .query(collection: "TestConversions")
                .where_greater_than("date", NOW)
                .wait_for_non_stale_results
                .all

      expect(results.size).to(eq(1))
      check_doc("TestConversions/2", results.first)
    end
  end

  it "supports custom id property" do
    id = nil

    store.conventions.add_id_property_resolver do |document_info|
      if document_info[:document_type] == TestCustomDocumentId.name
        "item_id"
      end
    end

    store.open_session do |session|
      doc = TestCustomDocumentId.new(nil, "New Item")

      session.store(doc)
      session.save_changes
      id = doc.item_id
    end

    store.open_session do |session|
      doc = session.load(id)

      expect(doc.item_id).to(eq(id))
      expect(doc.item_title).to(eq("New Item"))
    end
  end

  it "supports custom serializer" do
    id = nil

    store.conventions.add_id_property_resolver do |document_info|
      if document_info[:document_type] == TestCustomSerializer.name
        "item_id"
      end
    end

    store.conventions.add_attribute_serializer(CustomAttributeSerializer.new)

    store.open_session do |session|
      doc = TestCustomSerializer.new(nil, "New Item", [1, 2, 3])

      session.store(doc)
      session.save_changes
      id = doc.item_id
    end

    store.open_session do |session|
      doc = session.load(id)

      expect(id).to(eq(doc.item_id))
      expect(doc.item_title).to(eq("New Item"))
      expect(doc.item_options).to(eq([1, 2, 3]))

      raw_entities_and_metadata = session.instance_variable_get("@raw_entities_and_metadata")
      info = raw_entities_and_metadata[doc]
      raw_entity = info[:original_value]

      expect(raw_entity["itemTitle"]).to(eq("New Item"))
      expect(raw_entity["itemOptions"]).to(eq("1,2,3"))
    end
  end

  protected

  def make_document(id = nil, date = NOW)
    TestConversion.new(
      id, date, Foo.new("Foos/1", "Foo #1", 1), [
        Foo.new("Foos/2", "Foo #2", 2),
        Foo.new("Foos/3", "Foo #3", 3)
      ])
  end

  def check_foo(foo, id_of_foo = 1)
    expect(foo.is_a?(Foo)).to(eq(true))
    expect(foo.id).to(eq("Foos/#{id_of_foo}"))
    expect(foo.name).to(eq("Foo ##{id_of_foo}"))
    expect(foo.order).to(eq(id_of_foo))
  end

  def check_doc(id, doc)
    expect(doc.is_a?(TestConversion)).to(eq(true))
    expect(doc.id).to(eq(id))
    expect(doc.date.is_a?(DateTime)).to(eq(true))
    expect(doc.foos.is_a?(Array)).to(eq(true))

    check_foo(doc.foo)
    doc.foos.each_index { |index| check_foo(doc.foos[index], (index + 2)) }
  end
end
