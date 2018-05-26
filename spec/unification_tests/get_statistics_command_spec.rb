RSpec.describe RavenDB::GetStatisticsOperation, database: true, executor: true, rdbc_171: true do
  it "can get stats" do
    executor = create_executor(new_first_update_method: true)
    sample_data = RavenDB::CreateSampleDataOperation.new
    store.maintenance.send(sample_data)
    wait_for_indexing(store, store.database, nil)
    command = RavenDB::GetStatisticsCommand.new
    executor.execute_on_specific_node(command)
    stats = command.result
    expect(stats).not_to be_nil
    expect(stats.last_doc_etag).not_to be_nil
    expect(stats.last_doc_etag).to be > 0
    expect(stats.count_of_indexes).to eq 3
    expect(stats.count_of_documents).to eq 1059
    expect(stats.count_of_revision_documents).to be > 0
    expect(stats.count_of_documents_conflicts).to eq 0
    expect(stats.count_of_conflicts).to eq 0
    expect(stats.count_of_unique_attachments).to eq 17
    expect(stats.database_change_vector).not_to be_empty
    expect(stats.database_id).not_to be_empty
    expect(stats.pager).not_to be_empty
    expect(stats.last_indexing_time).not_to be_nil
    expect(stats.indexes).not_to be_nil
    expect(stats.size_on_disk.humane_size).not_to be_nil
    expect(stats.size_on_disk.size_in_bytes).not_to be_nil
    stats.indexes.each do |index_information|
      expect(index_information.name).not_to be_nil
      expect(index_information.stale?).to be false
      expect(index_information.state).not_to be_nil
      expect(index_information.lock_mode).not_to be_nil
      expect(index_information.priority).not_to be_nil
      expect(index_information.type).not_to be_nil
      expect(index_information.last_indexing_time).not_to be_nil
    end
  end

  SIDE_BY_SIDE_INDEX_NAME_PREFIX = "ReplacementOf/".freeze

  def wait_for_indexing(store, database, timeout)
    admin = store.maintenance.for_database(database)
    timeout ||= Time.now + 1.minute

    while timeout > Time.now
      # TODO: remove explicit parse_response
      database_statistics_json = admin.send(RavenDB::GetStatisticsOperation.new)
      database_statistics = RavenDB::GetStatisticsCommand.new.parse_response(database_statistics_json, from_cache: false)

      indexes = database_statistics.indexes.reject { |x| x.state == :disabled }
      if indexes.all? { |x| (!x.stale? && !x.name.start_with?(SIDE_BY_SIDE_INDEX_NAME_PREFIX)) }
        return
      end

      if database_statistics.indexes.any? { |x| x.state == :error }
        break
      end

      sleep(0.100)
    end

    raise "The indexes stayed stale" # TODO: get errors
  end
end
