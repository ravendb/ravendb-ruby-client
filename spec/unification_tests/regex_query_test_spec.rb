RSpec.describe RavenDB::WhereOperator::REGEX, database: true, rdbc_148: true do
  it "queries with regex from document query", rdbc_88: true do
    store.open_session do |session|
      session.store(RegexMe.new("I love dogs and cats"))
      session.store(RegexMe.new("I love cats"))
      session.store(RegexMe.new("I love dogs"))
      session.store(RegexMe.new("I love bats"))
      session.store(RegexMe.new("dogs love me"))
      session.store(RegexMe.new("cats love me"))
      session.save_changes
    end

    store.open_session do |session|
      query = session
              .advanced
              .document_query(RegexMe)
              .where_regex("text", "^[a-z ]{2,4}love")

      iq = query.get_index_query
      expect(iq.query).to eq("from RegexMes where regex(text, $p0)")
      expect(iq.query_parameters[:p0]).to eq("^[a-z ]{2,4}love")

      result = query.to_list
      expect(result.size).to eq(4)
    end
  end
end
