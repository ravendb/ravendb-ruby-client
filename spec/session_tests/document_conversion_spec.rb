RSpec.describe RavenDB::DocumentConventions, database: true do
  NOW = DateTime.now

  before do
    store.open_session do |session|
      session.store(make_document("TestConversions/1"))
      session.store(make_document("TestConversions/2", NOW.next_day))
      session.save_changes
    end
  end

  it "converts on load" do
    id = "TestConversions/1"

    store.open_session do |session|
      doc = session.load_new(TestConversion, id)
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
      doc = session.load_new(TestConversion, id)
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

      expect(results.size).to eq(1)
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
      doc = session.load_new(TestCustomDocumentId, id)

      expect(doc.item_id).to eq(id)
      expect(doc.item_title).to eq("New Item")
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
      doc = session.load_new(TestCustomSerializer, id)

      expect(id).to eq(doc.item_id)
      expect(doc.item_title).to eq("New Item")
      expect(doc.item_options).to eq([1, 2, 3])

      info = session.documents_by_entity[doc]
      raw_entity = info.document

      expect(raw_entity["itemTitle"]).to eq("New Item")
      expect(raw_entity["itemOptions"]).to eq("1,2,3")
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
    expect(foo).to be_kind_of(Foo)
    expect(foo.id).to eq("Foos/#{id_of_foo}")
    expect(foo.name).to eq("Foo ##{id_of_foo}")
    expect(foo.order).to eq(id_of_foo)
  end

  def check_doc(id, doc)
    expect(doc).to be_kind_of(TestConversion)
    expect(doc.id).to eq(id)
    expect(doc.date).to be_kind_of(DateTime)
    expect(doc.foos).to be_kind_of(Array)

    check_foo(doc.foo)
    doc.foos.each_index { |index| check_foo(doc.foos[index], (index + 2)) }
  end
end
