RSpec.describe RavenDB::DocumentSession, database: true do
  before do
    store.open_session do |session|
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

  it "loads existing document" do
    store.open_session do |session|
      product = session.load("Products/101")

      expect(product.name).to eq("test")
    end
  end

  it "does not load missing document" do
    store.open_session do |session|
      product = session.load("Products/0")

      expect(product).to be_nil
    end
  end

  it "loads few documents" do
    store.open_session do |session|
      products = session.load(["Products/101", "Products/10"])

      expect(products.size).to eq(2)
    end
  end

  it "loads few documents with duplicate id" do
    store.open_session do |session|
      products = session.load(["Products/101", "Products/10", "Products/101"])

      expect(products.size).to eq(3)
      products.each { |product| expect(product.nil?).to eq(false) }
    end
  end

  it "loads track entity" do
    store.open_session do |session|
      product = session.load("Products/101")

      expect(product).to be_kind_of(Product)
      expect(product.instance_variable_get("@metadata")["Raven-Ruby-Type"]).to eq("Product")
    end
  end

  it "loads track entity with nested object" do
    store.open_session do |session|
      company = session.load("Companies/1")

      expect(company).to be_kind_of(Company)
      expect(company.product).to be_kind_of(Product)
      expect(company.product.name).to eq("testing_nested")
    end
  end

  it "loads with includes" do
    store.open_session do |session|
      session.load("Orders/105", includes: ["product_id"])
      session.load("Products/101")

      expect(session.number_of_requests_in_session).to eq(1)
    end
  end
end
