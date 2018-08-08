RSpec.describe RavenDB::DocumentConventions, database: true do
  it "stores nested type" do
    id = "TestConversions/1"

    store.open_session do |session|
      session.store(TestConversion.new(id, DateTime.now, nil, []))
      session.save_changes
    end

    store.open_session do |session|
      doc = session.load_new(TestConversion, id)
      check_doc(id, doc)
    end
  end

  protected

  def check_doc(id, doc)
    expect(doc).to be_kind_of(TestConversion)
    expect(doc.id).to eq(id)
    expect(doc.date).to be_kind_of(DateTime)
    expect(doc.foos).to be_kind_of(Array)
  end
end
