require 'auth/certificate'

module RavenDB
  class AuthOptions
    attr_reader :certificate, :password

    def initialize(certificate, password = nil)
      @certificate = certificate
      @password = password
      @rsa_key = nil
    end

    def get_rsa_key
      @rsa_key ||= Certificate
         .create(@certificate, @password)
         .rsa_key
    end
  end

  class StoreAuthOptions < AuthOptions

  end

  class RequestAuthOptions < AuthOptions

  end
end