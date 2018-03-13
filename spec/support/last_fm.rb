class LastFm
  attr_accessor :id, :artist, :track_id,
                :title, :datetime_time, :tags

  def initialize(
    id = nil,
    artist = "",
    track_id = "",
    title = "",
    datetime_time = DateTime.now,
    tags = []
  )
    @id = id
    @artist = artist
    @track_id = track_id
    @title = title
    @datetime_time = datetime_time
    @tags = tags
  end
end
