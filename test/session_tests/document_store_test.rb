require 'date'
require 'ravendb'
require 'spec_helper'

class DocumentStoreTest < TestBase
  def setup
    super

    @_store.open_session do |session|
      product101 = Product.new("Products/101", "test")
      product10 = Product.new("Products/10", "test")
      order = Order.new("Orders/105", "testing_order", 92, "Products/101")
      company = Company.new("Companies/1", "test", Product.new(nil, "testing_nested"))

      session.store(product101)
      session.store(product10)
      session.store(order)
      session.store(company)
      session.save_changes
    end
  end

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
      metadata = product.instance_variable_get('@metadata')

      assert_equal(metadata['@id'], product.id)
      assert_equal(metadata['@collection'], 'Products')
      assert_equal(metadata['Raven-Ruby-Type'], 'Product')
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
      cached_documents = session.instance_variable_get('@raw_entities_and_metadata')
      info = cached_documents[product]

      refute(product.id.nil?)
      refute(product.id.empty?)
      assert_equal(info[:original_metadata]['@id'], product.id)
      refute(info[:original_value].key?('id'))
    end
  end

  def test_should_store_custom_fields_in_metadata
    expiration = DateTime.now.next_day.iso8601

    order = Order.new(nil, "New Order")
    order.instance_variable_set('@metadata', {'@expires' => expiration})

    @_store.open_session do |session|
      order = session.store(order)
      session.save_changes
    end

    @_store.open_session do |session|
      order = session.load(order.id)
      metadata = order.instance_variable_get('@metadata')

      assert(metadata.key?('@expires'))
      assert_equal(metadata['@expires'], expiration)
    end
  end

    #TODO: implement test_should_fail_after_delete when session.delete will be implemented
end