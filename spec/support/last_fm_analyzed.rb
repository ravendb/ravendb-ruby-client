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
      name: self.class.name,
      index_map: index_map,
      init_options: {
        fields: {
          "query" => RavenDB::IndexFieldOptions.new(RavenDB::FieldIndexingOption::SEARCH)
        }
      }
    )
  end

  def execute
    @store.operations.send(RavenDB::PutIndexesOperation.new(@index_definition))

    self
  end
end
