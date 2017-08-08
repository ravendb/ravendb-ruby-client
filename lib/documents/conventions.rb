module RavenDB
  class DocumentConventions
    MaxNumberOfRequestPerSession = 30
    RequestTimeout = 30;
    DefaultUseOptimisticConcurrency = true
    MaxLengthOfQueryUsingGetUrl = 1024 + 512
    IdentityPartsSeparator = "/"
    
    @SetIdOnlyIfPropertyIsDefined = false
    @DisableTopologyUpdates = false

    attr_accessor :SetIdOnlyIfPropertyIsDefined, :DisableTopologyUpdates

    def empty_change_vector
      return nil
    end

    def convert_to_document(json)
      return json
    end  
  end  
end  