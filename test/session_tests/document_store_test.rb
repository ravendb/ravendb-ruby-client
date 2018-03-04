require "date"
require "ravendb"
require "spec_helper"

class DocumentStoreTest < RavenDatabaseTest
  def test_should_store_without_id
    foo = nil

    @_store.open_session do |session|
      foo = session.store(Foo.new(nil, "test", 10))
      session.save_changes
    end

    @_store.open_session do |session|
      foo = session.load(foo.id)

      assert_equal(foo.name, "test")
    end
  end

  def test_should_store_with_id
    id = "TestingStore/1"
    foo = Foo.new(id, "test", 20)

    @_store.open_session do |session|
      session.store(foo, id)
      session.save_changes
    end

    @_store.open_session do |session|
      foo = session.load(id)

      assert_equal(foo.name, "test")
      assert_equal(foo.order, 20)
    end
  end

  def test_should_generate_id_and_set_collection
    product = Product.new(nil, "New Product")

    @_store.open_session do |session|
      session.store(product)
      session.save_changes

      assert(/^Products\/\d+(\-\w)?$/ =~ product.id)
    end

    @_store.open_session do |session|
      product = session.load(product.id)
      metadata = product.instance_variable_get("@metadata")

      assert_equal(metadata["@id"], product.id)
      assert_equal(metadata["@collection"], "Products")
      assert_equal(metadata["Raven-Ruby-Type"], "Product")
    end
  end

  def test_should_not_store_id_inside_document_json_only_in_metadata
    product = Product.new(nil, "New Product")

    @_store.open_session do |session|
      product = session.store(product)
      session.save_changes
    end

    @_store.open_session do |session|
      product = session.load(product.id)
      cached_documents = session.instance_variable_get("@raw_entities_and_metadata")
      info = cached_documents[product]

      refute(product.id.nil?)
      refute(product.id.empty?)
      assert_equal(info[:original_metadata]["@id"], product.id)
      refute(info[:original_value].key?("id"))
    end
  end

  def test_should_store_custom_fields_in_metadata
    expiration = DateTime.now.next_day.iso8601

    order = Order.new(nil, "New Order")
    order.instance_variable_set("@metadata", "@expires" => expiration)

    @_store.open_session do |session|
      order = session.store(order)
      session.save_changes
    end

    @_store.open_session do |session|
      order = session.load(order.id)
      metadata = order.instance_variable_get("@metadata")

      assert(metadata.key?("@expires"))
      assert_equal(metadata["@expires"], expiration)
    end
  end

  def test_should_fail_on_explicit_call_after_delete
    foo = nil
    key = "testingStore"

    @_store.open_session do |session|
      foo = Foo.new(key, "test", 20)
      session.store(foo)
      session.save_changes
    end

    @_store.open_session do |session|
      session.delete(key)

      assert_raises(RuntimeError) {session.store(foo)}
    end
  end

  def test_should_store_existing_doc_without_explicit_call
    key = "testingStore"

    @_store.open_session do |session|
      foo = Foo.new(key, "test", 20)
      session.store(foo)
      session.save_changes
    end

    @_store.open_session do |session|
      foo = session.load(key)
      foo.name = "name changed"
      foo.order = 10

      session.save_changes
    end

    @_store.open_session do |session|
      foo = session.load(key)

      assert_equal(foo.name, "name changed")
      assert_equal(foo.order, 10)
    end
  end

  def test_should_ignore_update_without_explicit_call_after_doc_deleted
    key = "testingStore"

    @_store.open_session do |session|
      foo = Foo.new(key, "test", 20)
      session.store(foo)
      session.save_changes
    end

    @_store.open_session do |session|
      foo = session.load(key)
      session.delete(foo)

      foo.name = "name changed"
      foo.order = 10

      refute_raises(RuntimeError) {session.save_changes}
    end

    @_store.open_session do |session|
      foo = session.load(key)
      assert_nil(foo)
    end
  end
end