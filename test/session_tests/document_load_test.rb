require "ravendb"
require "spec_helper"

class DocumentLoadTest < RavenDatabaseTest
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

  def test_should_load_existing_document
    @_store.open_session do |session|
      product = session.load("Products/101")

      assert_equal("test", product.name)
    end
  end

  def test_should_not_load_missing_document
    @_store.open_session do |session|
      product = session.load("Products/0")

      assert(product.nil?)
    end
  end

  def test_should_load_few_documents
    @_store.open_session do |session|
      products = session.load(["Products/101", "Products/10"])

      assert_equal(2, products.size)
    end
  end

  def test_should_load_few_documents_with_duplicate_id
    @_store.open_session do |session|
      products = session.load(["Products/101", "Products/10", "Products/101"])

      assert_equal(3, products.size)
      products.each { |product| refute(product.nil?) }
    end
  end

  def test_should_load_track_entity
    @_store.open_session do |session|
      product = session.load("Products/101")

      assert(product.is_a?(Product))
      assert_equal("Product", product.instance_variable_get("@metadata")["Raven-Ruby-Type"])
    end
  end

  def test_should_load_track_entity_with_nested_object
    @_store.open_session do |session|
      company = session.load("Companies/1")

      assert(company.is_a?(Company))
      assert(company.product.is_a?(Product))
      assert_equal("testing_nested", company.product.name)
    end
  end

  def test_should_load_with_includes
    @_store.open_session do |session|
      session.load("Orders/105", includes: ["product_id"])
      session.load("Products/101")

      assert_equal(1, session.number_of_requests_in_session)
    end
  end
end
