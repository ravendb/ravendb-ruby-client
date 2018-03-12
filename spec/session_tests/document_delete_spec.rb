describe RavenDB::DeleteDocumentCommand do
  IDS = [101, 10, 106, 107].freeze

  before do
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

    @change_vectors = products.map do |product|
      product.instance_variable_get("@metadata")["@change-vector"]
    end
  end

  after do
    @__test.teardown
  end

  let(:store) do
    @__test.store
  end

  it "deletes with key with save session" do
    id = "Products/101"

    store.open_session do |session|
      session.delete(id)
      session.save_changes

      product = session.load(id)
      expect(product.nil?).to(eq(true))
    end
  end

  it "deletes with key without save session" do
    id = "Products/10"

    store.open_session do |session|
      session.delete(id)

      product = session.load(id)
      expect(product.nil?).to(eq(true))
    end
  end

  it "deletes document after it has been changed and save session" do
    id = "Products/107"

    store.open_session do |session|
      product = session.load(id)
      product.name = "Testing"

      session.delete(product)
      session.save_changes

      product = session.load(id)
      expect(product.nil?).to(eq(true))
    end
  end

  it "fails delete document by id after it has been changed" do
    id = "Products/107"

    store.open_session do |session|
      product = session.load(id)
      product.name = "Testing"

      expect { session.delete(id) }.to(raise_error(RuntimeError))
    end
  end

  it "deletes with correct change vector" do
    store.open_session do |session|
      expect do
        IDS.each_index do |index|
          session.delete("Products/#{IDS[index]}", expected_change_vector: @change_vectors[index])
        end

        session.save_changes
      end.not_to(raise_error)
    end
  end

  it "fails delete with invalid change vector" do
    store.open_session do |session|
      expect do
        IDS.each_index do |index|
          session.delete("Products/#{IDS[index]}", expected_change_vector: "#{@change_vectors[index]}:BROKEN:VECTOR")
        end

        session.save_changes
      end.to(raise_error(RavenDB::ConcurrencyException))
    end
  end
end
