require "ravendb"
require "spec_helper"

describe RavenDB::DeleteDocumentCommand do
  IDS = [101, 10, 106, 107].freeze

  def setup
    @__test = RavenDatabaseTest.new(nil)
    @__test.setup

    products = nil

    store.open_session do |session|
      IDS.each { |id| session.store(Product.new("Products/#{id}", "test")) }
      session.save_changes
    end

    store.open_session do |session|
      products = session.load(IDS.map { |id| "Products/#{id}" })
    end

    @change_vectors = products.map { |product| product.instance_variable_get("@metadata")["@change-vector"] }
  end

  def teardown
    @__test.teardown
  end

  def store
    @__test.store
  end

  def test_should_delete_with_key_with_save_session
    id = "Products/101"

    store.open_session do |session|
      session.delete(id)
      session.save_changes

      product = session.load(id)
      assert(product.nil?)
    end
  end

  def test_should_delete_with_key_without_save_session
    id = "Products/10"

    store.open_session do |session|
      session.delete(id)

      product = session.load(id)
      assert(product.nil?)
    end
  end

  def test_should_delete_document_after_it_has_been_changed_and_save_session
    id = "Products/107"

    store.open_session do |session|
      product = session.load(id)
      product.name = "Testing"

      session.delete(product)
      session.save_changes

      product = session.load(id)
      assert(product.nil?)
    end
  end

  def test_should_fail_delete_document_by_id_after_it_has_been_changed
    id = "Products/107"

    store.open_session do |session|
      product = session.load(id)
      product.name = "Testing"

      assert_raises(RuntimeError) { session.delete(id) }
    end
  end

  def test_should_delete_with_correct_change_vector
    store.open_session do |session|
      refute_raises do
        IDS.each_index do |index|
          session.delete("Products/#{IDS[index]}", expected_change_vector: @change_vectors[index])
        end

        session.save_changes
      end
    end
  end

  def test_should_fail_delete_with_invalid_change_vector
    store.open_session do |session|
      assert_raises do
        IDS.each_index do |index|
          session.delete("Products/#{IDS[index]}", expected_change_vector: "#{@change_vectors[index]}:BROKEN:VECTOR")
        end

        session.save_changes
      end
    end
  end
end
