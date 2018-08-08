RSpec.describe RavenDB::PutDocumentCommand, database: true, rdbc_148: true do
  it "can put document using command" do
    user = User.new
    user.name = "Marcin"
    user.age = 30

    node = RavenDB::JsonSerializer.to_json(user)

    command = RavenDB::PutDocumentCommand.new(id: "users/1", document: node)
    store.get_request_executor.execute(command)
    result = command.result

    expect(result.id).to eq("users/1")
    expect(result.change_vector).not_to be_nil

    store.open_session do |session|
      loaded_user = session.load_new(User, "users/1")

      expect(loaded_user.name).to eq("Marcin")
    end
  end
end
