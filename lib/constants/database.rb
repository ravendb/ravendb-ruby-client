module RavenDB
  class AccessMode
    None = "None".freeze
    ReadOnly = "ReadOnly".freeze
    ReadWrite = "ReadWrite".freeze
    Admin = "Admin".freeze
  end

  class FieldIndexingOption
    No = "No".freeze
    Search = "Search".freeze
    Exact = "Exact".freeze
    Default = "Default".freeze
  end

  class FieldTermVectorOption
    No = "No".freeze
    Yes = "Yes".freeze
    WithPositions = "WithPositions".freeze
    WithOffsets = "WithOffsets".freeze
    WithPositionsAndOffsets = "WithPositionsAndOffsets".freeze
  end

  class IndexLockMode
    Unlock = "Unlock".freeze
    LockedIgnore = "LockedIgnore".freeze
    LockedError = "LockedError".freeze
    SideBySide = "SideBySide".freeze
  end

  class IndexPriority
    Low = "Low".freeze
    Normal = "Normal".freeze
    High = "High".freeze
  end

  class OperationStatus
    Completed = "Completed".freeze
    Faulted = "Faulted".freeze
    Running = "Running".freeze
  end
end
