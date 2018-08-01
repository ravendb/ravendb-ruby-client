RSpec.describe RavenDB::DocumentSession, database: true, rdbc_174: true do
  it "deletes document by entity" do
    store.open_session do |new_session|
      user = User.new
      user.name = "RavenDB"
      new_session.store(user, id: "users/1")
      new_session.save_changes

      user = new_session.load_new(User, "users/1")

      expect(user).not_to be_nil

      new_session.delete(user)
      new_session.save_changes

      null_user = new_session.load_new(User, "users/1")
      expect(null_user).to be_nil
    end
  end

  it "deletes document by id" do
    store.open_session do |new_session|
      user = User.new
      user.name = "RavenDB"
      new_session.store(user, id: "users/1")
      new_session.save_changes

      user = new_session.load_new(User, "users/1")

      expect(user).not_to be_nil

      new_session.delete("users/1")
      new_session.save_changes

      null_user = new_session.load_new(User, "users/1")
      expect(null_user).to be_nil
    end
  end
end
