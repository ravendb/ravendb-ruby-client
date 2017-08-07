class DocumentConventions
  MaxNumberOfRequestPerSession = 30
  RequestTimeout = 30;
  DefaultUseOptimisticConcurrency = true
  MaxLengthOfQueryUsingGetUrl = 1024 + 512
  IdentityPartsSeparator = "/"
  
  @SetIdOnlyIfPropertyIsDefined = false
  @DisableTopologyUpdates = false

  def empty_change_vector
    return nil
  end
end  