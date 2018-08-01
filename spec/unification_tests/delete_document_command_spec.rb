RSpec.describe RavenDB::DeleteDocumentCommand, database: true, rdbc_148: true do
  it "can delete document" do
    store.open_session do |session|
      user = User.new
      user.name = "Marcin"
      session.store(user, id: "users/1")
      session.save_changes
    end

    command = RavenDB::DeleteDocumentCommand.new("users/1")
    store.get_request_executor.execute(command)

    store.open_session do |session|
      loaded_user = session.load_new(User, "users/1")
      expect(loaded_user).to be_nil
    end
  end

  it "can delete document by etag" do
    change_vector = nil

    store.open_session do |session|
      user = User.new
      user.name = "Marcin"
      session.store(user, id: "users/1")
      session.save_changes

      change_vector = session.advanced.get_change_vector_for(user)
    end

    store.open_session do |session|
      loaded_user = session.load_new(User, "users/1")
      loaded_user.age = 5
      session.save_changes
    end

    command = RavenDB::DeleteDocumentCommand.new("users/1", change_vector)

    expect { store.get_request_executor.execute(command) }.to raise_error(RavenDB::ConcurrencyException)
  end
end
