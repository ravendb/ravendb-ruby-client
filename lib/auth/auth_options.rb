require 'auth/certificate'

module RavenDB
  class AuthOptions
    attr_reader :certificate, :password

    def initialize(certificate, password = nil)
      raise ArgumentError,
        "Invalid certificate provided" unless
          certificate.is_a?(Certificate)

      @certificate = certificate
      @password = password
    end
  end

  class StoreAuthOptions < AuthOptions

  end

  class RequestAuthOptions < AuthOptions

  end
end