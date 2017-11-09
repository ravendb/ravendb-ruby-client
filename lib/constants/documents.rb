module RavenDB
  class SearchOperator
    Or = 'OR'
    And = 'AND'
  end

  class QueryOperator < SearchOperator
    Not = 'NOT'
  end

  class QueryKeyword
    Select = 'SELECT'
    Distinct = 'DISTINCT'
    As = 'AS'
    From = 'FROM'
    Index = 'INDEX'
    Include = 'INCLUDE'
    Where = 'WHERE'
    Group = 'GROUP'
    Order = 'ORDER'
    Load = 'LOAD'
    By = 'BY'
    Asc = 'ASC'
    Desc = 'DESC'
    In = 'IN'
    Between = 'BETWEEN'
    All = 'ALL'
    Update = 'UPDATE'
  end

  class OrderingType
    String = 'string'
    Long = 'long'
    Double = 'double'
    AlphaNumeric = 'alphaNumeric'
  end

  class SpatialRelation
    Within = 'within'
    Contains = 'contains'
    Disjoint = 'disjoint'
    Intersects = 'intersects'
  end

  class WhereOperators < SpatialRelation
    Equals = 'equals'
    NotEquals = 'notEquals'
    GreaterThan = 'greaterThan'
    GreaterThanOrEqual = 'greaterThanOrEqual'
    LessThan = 'lessThan'
    LessThanOrEqual = 'lessThanOrEqual'
    In = 'in'
    AllIn = 'allIn'
    Between = 'between'
    Search = 'search'
    Lucene = 'lucene'
    StartsWith = 'startsWith'
    EndsWith = 'endsWith'
    Exists = 'exists'
  end

  class FieldConstants
    CustomSortFieldName = "__customSort"
    DocumentIdFieldName = "id()"
    ReduceKeyHashFieldName = "hash(key())"
    ReduceKeyValueFieldName = "key()"
    AllFields = "__all_fields"
    AllStoredFields = "__all_stored_fields"
    SpatialShapeFieldName = "spatial(shape)"
    RangeFieldSuffix = "_Range"
    RangeFieldSuffixLong = "_L_Range"
    RangeFieldSuffixDouble = "_D_Range"
    NullValue = "NULL_VALUE"
    EmptyString = "EMPTY_STRING"
  end

  class RavenServerEvent
    EVENT_QUERY_INITIALIZED = "query:initialized"
    EVENT_QUERY_FIELD_VALIDATED = "query:validated"
    EVENT_DOCUMENTS_QUERIED = "queried:documents"
    EVENT_DOCUMENT_FETCHED = "fetched:document"
    EVENT_INCLUDES_FETCHED = "fetched:includes"
    REQUEST_FAILED = "request:failed"
    TOPOLOGY_UPDATED = "topology:updated"
    NODE_STATUS_UPDATED = "node:status:updated"
  end  

  class PatchStatus
    DocumentDoesNotExist = "DocumentDoesNotExist"
    Created = "Created"
    Patched = "Patched"
    Skipped = "Skipped"
    NotModified = "NotModified"
  end

  class ConcurrencyCheckMode
    Auto = 'Auto'
    Forced = 'Forced'
    Disabled = 'Disabled'
  end
end