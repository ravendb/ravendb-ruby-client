RSpec.describe RavenDB::GetClusterTopologyCommand, database: true, rdbc_171: true do
  let :conventions do
    RavenDB::DocumentConventions.new
  end

  let :executor do
    RavenDB::RequestExecutor.new(initial_urls: store.urls,
                                 database_name: store.database,
                                 conventions: conventions,
                                 auth_options: store.auth_options,
                                 new_first_update_method: true)
  end

  it "can get topology" do
    command = RavenDB::GetClusterTopologyCommand.new

    executor.execute_on_specific_node(command)

    result = command.result

    expect(result).not_to be_nil
    expect(result.leader).not_to be_empty
    expect(result.node_tag).not_to be_empty

    topology = result.topology()

    expect(topology).not_to be_nil
    expect(topology.topology_id).not_to be_nil
    expect(topology.members.count).to eq(1)
    expect(topology.watchers.count).to eq(0)
    expect(topology.promotables.count).to eq(0)
  end
end
