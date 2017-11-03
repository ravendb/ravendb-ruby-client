module RavenDB
  class RQLWhereOperator
    Equals = "equals"
    In = "in"
    Between = "between"
    EqualBetween = "equal_between"
    Search = "search"
    StartsWith = "starts_with"
    EndsWith = "ends_with"
  end

  class RQLJoinOperator
    OR = "OR"
    AND = "AND"
    NOT = "NOT"

    def self.isAnd(operator)
      return self::AND == operator
    end

    def self.isOr(operator)
      return self::OR == operator
    end

    def self.isNot(operator)
      return self::NOT == operator
    end
  end

  class RavenServerEvent
    EVENT_QUERY_INITIALIZED = "query:initialized"
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