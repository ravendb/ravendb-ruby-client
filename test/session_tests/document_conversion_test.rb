require "date"
require "ravendb"
require "spec_helper"

class DocumentConversionTest < RavenDatabaseTest
  NOW = DateTime.now

  def setup
    super
    @_store.open_session do |session|
      session.store(make_document("TestConversions/1"))
      session.store(make_document("TestConversions/2", NOW.next_day))
      session.save_changes
    end
  end

  def test_should_convert_on_load
    id = "TestConversions/1"

    @_store.open_session do |session|
      doc = session.load(id)
      check_doc(id, doc)
    end
  end

  def test_should_convert_on_store_then_reload
    id = "TestConversions/New"

    @_store.open_session do |session|
      session.store(make_document(id))
      session.save_changes
    end

    @_store.open_session do |session|
      doc = session.load(id)
      check_doc(id, doc)
    end
  end

  def test_should_convert_on_query
    @_store.open_session do |session|
      results = session.query(
        collection: "TestConversions"
      )
                       .where_greater_than("date", NOW)
                       .wait_for_non_stale_results
                       .all

      assert_equal(results.size, 1)
      check_doc("TestConversions/2", results.first)
    end
  end

  def test_should_support_custom_id_property
    id = nil

    @_store.conventions.add_id_property_resolver do |document_info|
      if document_info[:document_type] == TestCustomDocumentId.name
        "item_id"
      end
    end

    @_store.open_session do |session|
      doc = TestCustomDocumentId.new(nil, "New Item")

      session.store(doc)
      session.save_changes
      id = doc.item_id
    end

    @_store.open_session do |session|
      doc = session.load(id)

      assert_equal(doc.item_id, id)
      assert_equal(doc.item_title, "New Item")
    end
  end

  def test_should_support_custom_serializer
    id = nil

    @_store.conventions.add_id_property_resolver do |document_info|
      if document_info[:document_type] == TestCustomSerializer.name
        "item_id"
      end
    end

    @_store.conventions.add_attribute_serializer(CustomAttributeSerializer.new)

    @_store.open_session do |session|
      doc = TestCustomSerializer.new(nil, "New Item", [1, 2, 3])

      session.store(doc)
      session.save_changes
      id = doc.item_id
    end

    @_store.open_session do |session|
      doc = session.load(id)

      assert_equal(doc.item_id, id)
      assert_equal(doc.item_title, "New Item")
      assert_equal(doc.item_options, [1, 2, 3])

      raw_entities_and_metadata = session.instance_variable_get("@raw_entities_and_metadata")
      info = raw_entities_and_metadata[doc]
      raw_entity = info[:original_value]

      assert_equal(raw_entity["itemTitle"], "New Item")
      assert_equal(raw_entity["itemOptions"], "1,2,3")
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
    assert(foo.is_a?(Foo))
    assert_equal(foo.id, "Foos/#{id_of_foo}")
    assert_equal(foo.name, "Foo ##{id_of_foo}")
    assert_equal(foo.order, id_of_foo)
  end

  def check_doc(id, doc)
    assert(doc.is_a?(TestConversion))
    assert_equal(doc.id, id)
    assert(doc.date.is_a?(DateTime))
    assert(doc.foos.is_a?(Array))

    check_foo(doc.foo)
    doc.foos.each_index { |index| check_foo(doc.foos[index], index + 2) }
  end
end
