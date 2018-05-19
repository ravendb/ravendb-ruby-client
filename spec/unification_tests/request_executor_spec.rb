require "database/operations/get_database_names_operation"

RSpec.describe RavenDB::RequestExecutor, database: true, rdbc_148: true, rdbc_171: true do
  let :conventions do
    RavenDB::DocumentConventions.new
  end

  let :executor do
    create_executor
  end

  it "failure should not block connection pool", rdbc_173: true do
    executor = create_executor(database_name: "no_such_db", new_first_update_method: true)

    40.times do
      expect do
        command = RavenDB::GetNextOperationIdCommand.new
        executor.execute_on_specific_node(command)
      end.to raise_error(RavenDB::RavenException)
    end

    expect do
      database_names_operation = RavenDB::GetDatabaseNamesOperation.new(start: 0, page_size: 20)
      command = database_names_operation.get_command(conventions: conventions)
      executor.execute_on_specific_node(command)
    end.to raise_error(RavenDB::DatabaseDoesNotExistException)
  end

  it "can issue many requests" do
    executor = create_executor(new_first_update_method: true)

    50.times do
      database_names_operation = RavenDB::GetDatabaseNamesOperation.new(start: 0, page_size: 20)
      command = database_names_operation.get_command(conventions: conventions)
      executor.execute_on_specific_node(command)
    end
  end

  it "can fetch databases names" do
    executor = create_executor(new_first_update_method: true)

    database_names_operation = RavenDB::GetDatabaseNamesOperation.new(start: 0, page_size: 20)
    command = database_names_operation.get_command(conventions: conventions)
    executor.execute_on_specific_node(command)

    db_names = command.result

    expect(db_names).to include(store.database)
  end

  it "throws when updating topology of not existing db" do
    executor = create_executor(database_name: "no_such_db", new_first_update_method: true)

    server_node = RavenDB::ServerNode.new
    server_node.url = store.urls[0]
    server_node.database = "no_such"

    expect do
      executor.update_topology_async(node: server_node, timeout: 5000).value!
    end.to raise_error(RavenDB::DatabaseDoesNotExistException)
  end

  it "throws when database does not exist" do
    executor = create_executor(database_name: "no_such_db")

    command = RavenDB::GetNextOperationIdCommand.new

    expect do
      executor.execute(command)
    end.to raise_error(RavenDB::DatabaseDoesNotExistException)
  end

  it "can create single node request executor" do
    executor = RavenDB::RequestExecutor.create_for_single_node(store.urls[0], store.database, store.auth_options,
                                                               new_first_update_method: true,
                                                               disable_configuration_updates: true)

    nodes = executor.topology_nodes

    expect(nodes.size).to eq(1)

    server_node = nodes[0]
    expect(server_node.url).to eq(store.urls[0])
    expect(server_node.database).to eq(store.database)

    command = RavenDB::GetNextOperationIdCommand.new

    executor.execute_on_specific_node(command)

    expect(command.result).not_to be_nil
  end

  it "can choose online node" do
    url = store.urls[0]

    prefix = default_url.downcase.split("//")[0]

    initial_urls = ["#{prefix}//no_such_host:8080", "#{prefix}//another_offline:8080", url]
    executor = create_executor(initial_urls: initial_urls, new_first_update_method: true)

    command = RavenDB::GetNextOperationIdCommand.new
    executor.execute_on_specific_node(command)

    expect(command.result).not_to be_nil

    topology_nodes = executor.topology_nodes

    expect(topology_nodes.size).to eq(1)
    expect(topology_nodes[0].url).to eq(url)
    expect(executor.url).to eq(url)
  end

  it "fails when server is offline" do
    expect do
      # don't even start server
      initial_urls = ["http://no_such_host:8081"]
      executor = create_executor(initial_urls: initial_urls, database_name: "db1", new_first_update_method: true)
      command =  RavenDB::GetNextOperationIdCommand.new

      executor.execute_on_specific_node(command)
    end.to raise_error(RavenDB::AllTopologyNodesDownException)
  end

  def create_executor(initial_urls: store.urls, database_name: store.database, new_first_update_method: false)
    RavenDB::RequestExecutor.new(initial_urls: initial_urls,
                                 database_name: database_name,
                                 conventions: conventions,
                                 auth_options: store.auth_options,
                                 new_first_update_method: new_first_update_method)
  end
end
