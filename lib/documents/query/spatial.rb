require 'constants/documents'
require 'documents/query/query_tokens'

module RavenDB
  class SpatialCriteria
    def self.relates_to_shape(shape_wkt, relation, dist_error_percent = SpatialConstants::DefaultDistanceErrorPct)
      WktCriteria.new(shape_wkt, relation, dist_error_percent)
    end

    def self.intersects(shape_wkt, dist_error_percent = SpatialConstants::DefaultDistanceErrorPct)
      relates_to_shape(shape_wkt, SpatialRelation::Intersects, dist_error_percent)
    end

    def self.contains(shape_wkt, dist_error_percent = SpatialConstants::DefaultDistanceErrorPct)
      relates_to_shape(shape_wkt, SpatialRelation::Contains, dist_error_percent)
    end

    def self.disjoint(shape_wkt, dist_error_percent = SpatialConstants::DefaultDistanceErrorPct)
      relates_to_shape(shape_wkt, SpatialRelation::Disjoint, dist_error_percent)
    end

    def self.within(shape_wkt, dist_error_percent = SpatialConstants::DefaultDistanceErrorPct)
      relates_to_shape(shape_wkt, SpatialRelation::Within, dist_error_percent)
    end

    def self.within_radius(radius, latitude, longitude, radius_units = nil, dist_error_percent = SpatialConstants::DefaultDistanceErrorPct)
      CircleCriteria.new(radius, latitude, longitude, radius_units, SpatialRelations::Within, dist_error_percent)
    end

    def initialize(relation, dist_error_percent)
      @relation = relation
      @distance_error_pct = dist_error_percent
    end

    def get_shape_token(&spatial_parameter_name_generator)
      raise NotImplementedError, "You should implement get_shape_token method"
    end

    def to_query_token(field_name, &spatial_parameter_name_generator)
      relation_token = nil
      shape_token = get_shape_token(&spatial_parameter_name_generator)

      case @relation
        when SpatialRelations::Intersects
          relation_token = WhereToken::intersects(field_name, shape_token, @distance_error_pct)
        when SpatialRelations::Contains
          relation_token = WhereToken::contains(field_name, shape_token, @distance_error_pct)
        when SpatialRelations::Within
          relation_token = WhereToken::within(field_name, shape_token, @distance_error_pct)
        when SpatialRelations::Disjoint
          relation_token = WhereToken::disjoint(field_name, shape_token, @distance_error_pct)
      end

      relation_token
    end
  end

  class CircleCriteria < SpatialCriteria
    def initialize(radius, latitude, longitude, radius_units = SpatialUnit::Kilometers, relation, dist_error_percent)
      super(relation, dist_error_percent)

      @radius = radius
      @latitude = latitude
      @longitude = longitude
      @radius_units = radius_units || SpatialUnits::Kilometers
    end

    def get_shape_token(&spatial_parameter_name_generator)
      ShapeToken::circle(
        spatial_parameter_name_generator.call(@radius),
        spatial_parameter_name_generator.call(@latitude),
        spatial_parameter_name_generator.call(@longitude),
        @radius_units
      )
    end
  end

  class WktCriteria < SpatialCriteria
    def initialize(shape_wkt, relation, distance_error_pct)
      super(relation, distance_error_pct)

      @shape_wkt = shape_wkt
    end

    def get_shape_token(&spatial_parameter_name_generator)
      ShapeToken::wkt(spatial_parameter_name_generator.call(@shape_wkt))
    end
  end
end