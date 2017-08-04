module RavenDB

  class AccessMode
    None = "None"
    ReadOnly = "ReadOnly"
    ReadWrite = "ReadWrite"
    Admin = "Admin"
  end

  class ConcurrencyCheckMode
    Auto = "Auto"
    Forced = "Forced"
    Disabled = "Disabled"
  end

  class FieldIndexingOption
    No = "No"
    Analyzed = "Analyzed"
    NotAnalyzed = "NotAnalyzed"
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

  class SortOptions
    None = "None"
    Str = "String"
    Numeric = "Numeric"
  end  

  class OperationStatus
    Completed = "Completed"
    Faulted = "Faulted"
    Running = "Running"
  end
end  