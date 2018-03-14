module RavenDB
  class SearchOperator
    OR = "OR".freeze
    AND = "AND".freeze
  end

  class QueryOperator < SearchOperator
    NOT = "NOT".freeze
  end

  class QueryKeyword
    SELECT = "SELECT".freeze
    DISTINCT = "DISTINCT".freeze
    AS = "AS".freeze
    FROM = "FROM".freeze
    INDEX = "INDEX".freeze
    INCLUDE = "INCLUDE".freeze
    WHERE = "WHERE".freeze
    GROUP = "GROUP".freeze
    ORDER = "ORDER".freeze
    LOAD = "LOAD".freeze
    BY = "BY".freeze
    ASC = "ASC".freeze
    DESC = "DESC".freeze
    IN = "IN".freeze
    BETWEEN = "BETWEEN".freeze
    ALL = "ALL".freeze
    UPDATE = "UPDATE".freeze
  end

  class OrderingType
    STRING = "string".freeze
    LONG = "long".freeze
    DOUBLE = "double".freeze
    ALPHA_NUMERIC = "alphaNumeric".freeze
  end

  class SpatialRelation
    WITHIN = "within".freeze
    CONTAINS = "contains".freeze
    DISJOINT = "disjoint".freeze
    INTERSECTS = "intersects".freeze
  end

  class WhereOperator < SpatialRelation
    EQUALS = "equals".freeze
    NOT_EQUALS = "notEquals".freeze
    GREATER_THAN = "greaterThan".freeze
    GREATER_THAN_OR_EQUAL = "greaterThanOrEqual".freeze
    LESS_THAN = "lessThan".freeze
    LESS_THAN_OR_EQUAL = "lessThanOrEqual".freeze
    IN = "in".freeze
    ALL_IN = "allIn".freeze
    BETWEEN = "between".freeze
    SEARCH = "search".freeze
    LUCENE = "lucene".freeze
    STARTS_WITH = "startsWith".freeze
    ENDS_WITH = "endsWith".freeze
    EXISTS = "exists".freeze
  end

  class FieldConstants
    CUSTOM_SORT_FIELD_NAME = "__customSort".freeze
    DOCUMENT_ID_FIELD_NAME = "id()".freeze
    REDUCE_KEY_HASH_FIELD_NAME = "hash(key())".freeze
    REDUCE_KEY_VALUE_FIELD_NAME = "key()".freeze
    ALL_FIELDS = "__all_fields".freeze
    ALL_STORED_FIELDS = "__all_stored_fields".freeze
    SPATIAL_SHAPE_FIELD_NAME = "spatial(shape)".freeze
    RANGE_FIELD_SUFFIX = "_Range".freeze
    RANGE_FIELD_SUFFIX_LONG = "_L_Range".freeze
    RANGE_FIELD_SUFFIX_DOUBLE = "_D_Range".freeze
    NULL_VALUE = "NULL_VALUE".freeze
    EMPTY_STRING = "EMPTY_STRING".freeze
  end

  class SpatialConstants
    DEFAULT_DISTANCE_ERROR_PCT = 0.025
    EARTH_MEAN_RADIUS_KM = 6371.0087714
    MILES_TO_KM = 1.60934
  end

  class SpatialUnit
    KILOMETERS = "Kilometers".freeze
    MILES = "Miles".freeze
  end

  class RavenServerEvent
    EVENT_QUERY_INITIALIZED = "query:initialized".freeze
    EVENT_QUERY_FIELD_VALIDATED = "query:validated".freeze
    EVENT_DOCUMENTS_QUERIED = "queried:documents".freeze
    EVENT_DOCUMENT_FETCHED = "fetched:document".freeze
    EVENT_INCLUDES_FETCHED = "fetched:includes".freeze
    REQUEST_FAILED = "request:failed".freeze
    TOPOLOGY_UPDATED = "topology:updated".freeze
    NODE_STATUS_UPDATED = "node:status:updated".freeze
  end

  class PatchStatus
    DOCUMENT_DOES_NOT_EXIST = "DocumentDoesNotExist".freeze
    CREATED = "Created".freeze
    PATCHED = "Patched".freeze
    SKIPPED = "Skipped".freeze
    NOT_MODIFIED = "NotModified".freeze
  end

  class ConcurrencyCheckMode
    AUTO = "Auto".freeze
    FORCED = "Forced".freeze
    DISABLED = "Disabled".freeze
  end

  class AttachmentType
    DOCUMENT = "Document".freeze
    REVISION = "Revision".freeze

    def self.is_document(type)
      type == DOCUMENT
    end

    def self.is_revision(type)
      type == REVISION
    end
  end
end
