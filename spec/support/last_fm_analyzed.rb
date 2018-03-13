class LastFmAnalyzed
  def initialize(store, test)
    index_map = "from song in docs.LastFms "\
      "select new {"\
      "query = new object[] {"\
      "song.artist,"\
      "((object)song.datetime_time),"\
      "song.tags,"\
      "song.title,"\
      "song.track_id}}"

    @test = test
    @store = store
    @index_definition = RavenDB::IndexDefinition.new(
      self.class.name, index_map, nil,
      fields: {
        "query" => RavenDB::IndexFieldOptions.new(RavenDB::FieldIndexingOption::Search)
      }
    )
  end

  def execute
    @store.operations.send(RavenDB::PutIndexesOperation.new(@index_definition))

    self
  end
end
