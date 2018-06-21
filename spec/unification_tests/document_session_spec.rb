RSpec.describe RavenDB::DocumentSession, database: true, rdbc_174: true do
  it "can load with includes" do
    foo_id = nil
    bar_id = nil

    store.open_session do |session|
      foo = Foo.new
      foo.name = "Beginning"
      session.store(foo)

      foo_id = session.advanced.get_document_id(foo)
      expect(foo_id).not_to be_nil

      bar = Bar.new
      bar.name = "End"
      bar.foo_id = foo_id

      session.store(bar)

      bar_id = session.advanced.get_document_id(bar)
      expect(bar_id).not_to be_nil

      session.save_changes
    end

    store.open_session do |new_session|
      # TODO: map foo_id -> fooId ?
      bar = new_session.include("foo_id").load(Bar, [bar_id])

      expect(bar).not_to be_nil
      expect(bar.size).to eq(1)
      expect(bar[bar_id]).not_to be_nil
      expect(bar[bar_id].foo_id).to eq(foo_id)

      num_of_requests = new_session.advanced.number_of_requests

      # TODO: -> load
      foo = new_session.load_new(Foo, bar[bar_id].foo_id)

      expect(foo).not_to be_nil
      expect(foo.name).to eq("Beginning")

      expect(new_session.advanced.number_of_requests).to eq(num_of_requests)
    end
  end
end
