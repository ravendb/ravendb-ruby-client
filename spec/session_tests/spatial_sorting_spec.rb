RSpec.describe RavenDB::SpatialCriteria, database: true, rdbc_145: true do
  FILTERED_LAT = 44.419575
  FILTERED_LNG = 34.042618
  SORTED_LAT = 44.417398
  SORTED_LNG = 34.042575
  FILTERED_RADIUS = 100

  before do
    shops = [
      Shop.new("Shops/1-A", 44.420678, 34.042490),
      Shop.new("Shops/2-A", 44.419712, 34.042232),
      Shop.new("Shops/3-A", 44.418686, 34.043219)
    ]

    fields = {"tag" => RavenDB::IndexFieldOptions.new(RavenDB::FieldIndexingOption::EXACT)}

    index_map = "from e in docs.Shops select new { e.venue, coordinates = CreateSpatialField(e.latitude, e.longitude) }"
    index_definition = RavenDB::IndexDefinition.new(
      name: "eventsByLatLng",
      index_map: index_map,
      init_options: {fields: fields}
    )
    store.operations.send(RavenDB::PutIndexesOperation.new(index_definition))

    index_map = "from e in docs.Shops select new { e.venue, mySpacialField = CreateSpatialField(e.latitude, e.longitude) }"
    index_definition2 = RavenDB::IndexDefinition.new(
      name: "eventsByLatLngWSpecialField",
      index_map: index_map,
      init_options: {fields: fields}
    )
    store.operations.send(RavenDB::PutIndexesOperation.new(index_definition2))

    store.open_session do |session|
      shops.each do |shop|
        session.store(shop)
      end
      session.save_changes
    end
  end

  it "can filter by location and sort by distance from different point with doc query" do
    store.open_session do |session|
      query_shape = get_query_shape_from_lat_lon(FILTERED_LAT, FILTERED_LNG, FILTERED_RADIUS)

      shops = session
              .query(collection: "Shops", index_name: "eventsByLatLng")
              .spatial("coordinates", RavenDB::SpatialCriteria.within(query_shape))
              .order_by_distance("coordinates", SORTED_LAT, SORTED_LNG)
              .wait_for_non_stale_results
              .all

      # shop/1:0.36KM, shop/2:0.26KM, shop/3 0.15KM from (34.042575,  44.417398)
      expect(shops.map(&:id)).to eq(["Shops/3-A", "Shops/2-A", "Shops/1-A"])
    end
  end

  it "can sort by distance w/o filtering with doc query" do
    store.open_session do |session|
      shops = session
              .query(collection: "Shops", index_name: "eventsByLatLng")
              .order_by_distance("coordinates", SORTED_LAT, SORTED_LNG)
              .wait_for_non_stale_results
              .all

      # shop/1:0.36KM, shop/2:0.26KM, shop/3 0.15KM from (34.042575,  44.417398)
      expect(shops.map(&:id)).to eq(["Shops/3-A", "Shops/2-A", "Shops/1-A"])
    end
  end

  it "can sort by distance w/o filtering with doc query by specified field" do
    store.open_session do |session|
      shops = session
              .query(collection: "Shops", index_name: "eventsByLatLngWSpecialField")
              .order_by_distance("mySpacialField", SORTED_LAT, SORTED_LNG)
              .wait_for_non_stale_results
              .all

      # shop/1:0.36KM, shop/2:0.26KM, shop/3 0.15KM from (34.042575,  44.417398)
      expect(shops.map(&:id)).to eq(["Shops/3-A", "Shops/2-A", "Shops/1-A"])
    end
  end

  it "can sort by distance w/o filtering" do
    store.open_session do |session|
      shops = session
              .query(collection: "Shops", index_name: "eventsByLatLng")
              .order_by_distance("coordinates", FILTERED_LAT, FILTERED_LNG)
              .wait_for_non_stale_results
              .all

      # shop/1:0.12KM, shop/2:0.03KM, shop/3 0.11KM from (34.042618,  44.419575)
      expect(shops.map(&:id)).to eq(["Shops/2-A", "Shops/3-A", "Shops/1-A"])
    end
  end

  it "can sort by distance (descending) w/o filtering" do
    store.open_session do |session|
      shops = session
              .query(collection: "Shops", index_name: "eventsByLatLng")
              .order_by_distance_descending("coordinates", FILTERED_LAT, FILTERED_LNG)
              .wait_for_non_stale_results
              .all

      # shop/1:0.12KM, shop/2:0.03KM, shop/3 0.11KM from (34.042618,  44.419575)
      expect(shops.map(&:id)).to eq(["Shops/1-A", "Shops/3-A", "Shops/2-A"])
    end
  end

  it "can sort by distance w/o filtering by specified field" do
    store.open_session do |session|
      shops = session
              .query(collection: "Shops", index_name: "eventsByLatLngWSpecialField")
              .order_by_distance("mySpacialField", FILTERED_LAT, FILTERED_LNG)
              .wait_for_non_stale_results
              .all

      # shop/1:0.12KM, shop/2:0.03KM, shop/3 0.11KM from (34.042618,  44.419575)
      expect(shops.map(&:id)).to eq(["Shops/2-A", "Shops/3-A", "Shops/1-A"])
    end
  end

  it "can sort by distance (descending) w/o filtering by specified field" do
    store.open_session do |session|
      shops = session
              .query(collection: "Shops", index_name: "eventsByLatLngWSpecialField")
              .order_by_distance_descending("mySpacialField", FILTERED_LAT, FILTERED_LNG)
              .wait_for_non_stale_results
              .all

      # shop/1:0.12KM, shop/2:0.03KM, shop/3 0.11KM from (34.042618,  44.419575)
      expect(shops.map(&:id)).to eq(["Shops/1-A", "Shops/3-A", "Shops/2-A"])
    end
  end

  def get_query_shape_from_lat_lon(lat, lng, radius)
    "Circle(#{lng} #{lat} d=#{radius})"
  end
end
