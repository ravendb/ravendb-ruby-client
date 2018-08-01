RSpec.describe RavenDB::DeleteDocumentCommand, database: true do
  IDS = [101, 10, 106, 107].freeze

  before do
    products = nil

    store.open_session do |session|
      IDS.each { |id| session.store(Product.new("Products/#{id}", "test")) }
      session.save_changes
    end

    store.open_session do |session|
      products = session.load_new(Product, IDS.map { |id| "Products/#{id}" })

      @change_vectors = products.map do |_id, product|
        session.documents_by_entity[product].change_vector
      end
    end
  end

  it "deletes with key with save session" do
    id = "Products/101"

    store.open_session do |session|
      session.delete(id)
      session.save_changes

      product = session.load_new(Product, id)
      expect(product).to be_nil
    end
  end

  it "deletes with key without save session" do
    id = "Products/10"

    store.open_session do |session|
      session.delete(id)

      product = session.load_new(Product, id)
      expect(product).to be_nil
    end
  end

  it "deletes document after it has been changed and save session" do
    id = "Products/107"

    store.open_session do |session|
      product = session.load_new(Product, id)
      product.name = "Testing"

      session.delete(product)
      session.save_changes

      product = session.load_new(Product, id)
      expect(product).to be_nil
    end
  end

  it "fails to delete document by id after it has been changed" do
    id = "Products/107"

    store.open_session do |session|
      product = session.load_new(Product, id)
      product.name = "Testing"

      expect { session.delete(id) }.to raise_error(RuntimeError)
    end
  end

  it "deletes with correct change vector" do
    store.open_session do |session|
      expect do
        IDS.each_index do |index|
          session.delete("Products/#{IDS[index]}", expected_change_vector: @change_vectors[index])
        end

        session.save_changes
      end.not_to raise_error
    end
  end

  it "fails delete with invalid change vector" do
    store.open_session do |session|
      expect do
        IDS.each_index do |index|
          session.delete("Products/#{IDS[index]}", expected_change_vector: "#{@change_vectors[index]}:BROKEN:VECTOR")
        end

        session.save_changes
      end.to raise_error(RavenDB::ConcurrencyException)
    end
  end
end
