RSpec.describe RavenDB::DocumentStore, database: true do
  it "stores without id" do
    foo = nil

    store.open_session do |session|
      foo = session.store(Foo.new(nil, "test", 10))
      session.save_changes
    end

    store.open_session do |session|
      foo = session.load_new(Foo, foo.id)

      expect(foo.name).to eq("test")
    end
  end

  it "stores with id" do
    id = "TestingStore/1"
    foo = Foo.new(id, "test", 20)

    store.open_session do |session|
      session.store(foo, id: id)
      session.save_changes
    end

    store.open_session do |session|
      foo = session.load_new(Foo, id)

      expect(foo.name).to eq("test")
      expect(foo.order).to eq(20)
    end
  end

  it "generates id and set collection" do
    product = Product.new(nil, "New Product")

    store.open_session do |session|
      session.store(product)
      session.save_changes

      expect(/^products\/\d+(\-\w)?$/ =~ product.id).to be_truthy
    end

    store.open_session do |session|
      product = session.load_new(Product, product.id)
      metadata = product.instance_variable_get("@metadata")

      expect(metadata["@id"]).to eq(product.id)
      expect(metadata["@collection"]).to eq("Products")
      expect(metadata["Raven-Ruby-Type"]).to eq("Product")
    end
  end

  it "does not store id inside document json only in metadata" do
    product = Product.new(nil, "New Product")

    store.open_session do |session|
      product = session.store(product)
      session.save_changes
    end

    store.open_session do |session|
      product = session.load_new(Product, product.id)
      cached_documents = session.instance_variable_get("@documents_by_id")
      info = cached_documents[product.id]

      expect(product.id.nil?).to eq(false)
      expect(product.id.empty?).to eq(false)
      expect(product.id).to eq(info.metadata["@id"])
      expect(info.document.key?("id")).to eq(false)
    end
  end

  it "stores custom fields in metadata" do
    expiration = DateTime.now.next_day.iso8601

    order = Order.new(nil, "New Order")
    order.instance_variable_set("@metadata", "@expires" => expiration)

    store.open_session do |session|
      order = session.store(order)
      session.save_changes
    end

    store.open_session do |session|
      order = session.load_new(Order, order.id)
      metadata = order.instance_variable_get("@metadata")

      expect(metadata).to include("@expires")
      expect(expiration).to eq(metadata["@expires"])
    end
  end

  it "fails on explicit call after delete" do
    foo = nil
    key = "testingStore"

    store.open_session do |session|
      foo = Foo.new(key, "test", 20)
      session.store(foo)
      session.save_changes
    end

    store.open_session do |session|
      session.delete(key)

      expect { session.store(foo) }.to raise_error(RuntimeError)
    end
  end

  it "stores existing doc without explicit call" do
    key = "testingStore"

    store.open_session do |session|
      foo = Foo.new(key, "test", 20)
      session.store(foo)
      session.save_changes
    end

    store.open_session do |session|
      foo = session.load_new(Foo, key)
      foo.name = "name changed"
      foo.order = 10

      session.save_changes
    end

    store.open_session do |session|
      foo = session.load_new(Foo, key)

      expect(foo.name).to eq("name changed")
      expect(foo.order).to eq(10)
    end
  end

  it "ignores update without explicit call after doc deleted" do
    key = "testingStore"

    store.open_session do |session|
      foo = Foo.new(key, "test", 20)
      session.store(foo)
      session.save_changes
    end

    store.open_session do |session|
      foo = session.load_new(Foo, key)
      session.delete(foo)

      foo.name = "name changed"
      foo.order = 10

      expect { session.save_changes }.not_to raise_error
    end

    store.open_session do |session|
      foo = session.load_new(Order, key)
      expect(foo).to be_nil
    end
  end
end
