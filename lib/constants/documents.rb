module RavenDB
  class SearchOperator
    Or = "OR".freeze
    And = "AND".freeze
  end

  class QueryOperator < SearchOperator
    Not = "NOT".freeze
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
    String = "string".freeze
    Long = "long".freeze
    Double = "double".freeze
    AlphaNumeric = "alphaNumeric".freeze
  end

  class SpatialRelation
    Within = "within".freeze
    Contains = "contains".freeze
    Disjoint = "disjoint".freeze
    Intersects = "intersects".freeze
  end

  class WhereOperator < SpatialRelation
    Equals = "equals".freeze
    NotEquals = "notEquals".freeze
    GreaterThan = "greaterThan".freeze
    GreaterThanOrEqual = "greaterThanOrEqual".freeze
    LessThan = "lessThan".freeze
    LessThanOrEqual = "lessThanOrEqual".freeze
    In = "in".freeze
    AllIn = "allIn".freeze
    Between = "between".freeze
    Search = "search".freeze
    Lucene = "lucene".freeze
    StartsWith = "startsWith".freeze
    EndsWith = "endsWith".freeze
    Exists = "exists".freeze
  end

  class FieldConstants
    CustomSortFieldName = "__customSort".freeze
    DocumentIdFieldName = "id()".freeze
    ReduceKeyHashFieldName = "hash(key())".freeze
    ReduceKeyValueFieldName = "key()".freeze
    AllFields = "__all_fields".freeze
    AllStoredFields = "__all_stored_fields".freeze
    SpatialShapeFieldName = "spatial(shape)".freeze
    RangeFieldSuffix = "_Range".freeze
    RangeFieldSuffixLong = "_L_Range".freeze
    RangeFieldSuffixDouble = "_D_Range".freeze
    NullValue = "NULL_VALUE".freeze
    EmptyString = "EMPTY_STRING".freeze
  end

  class SpatialConstants
    DefaultDistanceErrorPct = 0.025
    EarthMeanRadiusKm = 6371.0087714
    MilesToKm = 1.60934
  end

  class SpatialUnit
    Kilometers = "Kilometers".freeze
    Miles = "Miles".freeze
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
    DocumentDoesNotExist = "DocumentDoesNotExist".freeze
    Created = "Created".freeze
    Patched = "Patched".freeze
    Skipped = "Skipped".freeze
    NotModified = "NotModified".freeze
  end

  class ConcurrencyCheckMode
    Auto = "Auto".freeze
    Forced = "Forced".freeze
    Disabled = "Disabled".freeze
  end

  class AttachmentType
    Document = "Document".freeze
    Revision = "Revision".freeze

    def self.is_document(type)
      type == Document
    end

    def self.is_revision(type)
      type == Revision
    end
  end
end
