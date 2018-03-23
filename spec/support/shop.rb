class Shop
  attr_accessor :id
  attr_accessor :latitude
  attr_accessor :longitude

  def initialize(id = nil, latitude = nil, longitude = nil)
    @id = id
    @latitude = latitude
    @longitude = longitude
  end
end
