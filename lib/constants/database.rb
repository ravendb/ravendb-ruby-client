module RavenDB
  class AccessMode
    None = "None"
    ReadOnly = "ReadOnly"
    ReadWrite = "ReadWrite"
    Admin = "Admin"
  end

  class FieldIndexingOption
    No = "No"
    Search = "Search"
    Exact = "Exact"
    Default = "Default"
  end

  class FieldTermVectorOption
    No = "No"
    Yes = "Yes"
    WithPositions = "WithPositions"
    WithOffsets = "WithOffsets"
    WithPositionsAndOffsets = "WithPositionsAndOffsets"
  end

  class IndexLockMode
    Unlock = "Unlock"
    LockedIgnore = "LockedIgnore"
    LockedError = "LockedError"
    SideBySide = "SideBySide"
  end

  class IndexPriority
    Low = "Low"
    Normal = "Normal"
    High = "High"
  end

  class OperationStatus
    Completed = "Completed"
    Faulted = "Faulted"
    Running = "Running"
  end
end  