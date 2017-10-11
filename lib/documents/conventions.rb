module RavenDB
  class DocumentConventions
    MaxNumberOfRequestPerSession = 30
    RequestTimeout = 30
    DefaultUseOptimisticConcurrency = true
    MaxLengthOfQueryUsingGetUrl = 1024 + 512
    IdentityPartsSeparator = "/"
    
    attr_accessor :SetIdOnlyIfPropertyIsDefined, :DisableTopologyUpdates

    def initialize
      @SetIdOnlyIfPropertyIsDefined = false
      @DisableTopologyUpdates = false
    end  

    def empty_change_vector
      nil
    end

    def convert_to_document(json)
      json
    end  
  end  
end  