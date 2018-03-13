module RavenDB
  class AccessMode
    NONE = "None".freeze
    READ_ONLY = "ReadOnly".freeze
    READ_WRITE = "ReadWrite".freeze
    ADMIN = "Admin".freeze
  end

  class FieldIndexingOption
    NO = "No".freeze
    SEARCH = "Search".freeze
    EXACT = "Exact".freeze
    DEFAULT = "Default".freeze
  end

  class FieldTermVectorOption
    NO = "No".freeze
    YES = "Yes".freeze
    WITH_POSITIONS = "WithPositions".freeze
    WITH_OFFSETS = "WithOffsets".freeze
    WITH_POSITIONS_AND_OFFSETS = "WithPositionsAndOffsets".freeze
  end

  class IndexLockMode
    UNLOCK = "Unlock".freeze
    LOCKED_IGNORE = "LockedIgnore".freeze
    LOCKED_ERROR = "LockedError".freeze
    SIDE_BY_SIDE = "SideBySide".freeze
  end

  class IndexPriority
    LOW = "Low".freeze
    NORMAL = "Normal".freeze
    HIGH = "High".freeze
  end

  class OperationStatus
    COMPLETED = "Completed".freeze
    FAULTED = "Faulted".freeze
    RUNNING = "Running".freeze
  end
end
