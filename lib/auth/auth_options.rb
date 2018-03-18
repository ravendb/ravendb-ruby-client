require "auth/certificate"

module RavenDB
  class AuthOptions
    attr_reader :certificate, :password

    def initialize(certificate, password = nil)
      @certificate = certificate || nil
      @password = password
      @_cert_wrapper = nil
    end

    def rsa_key
      cert_wrapper.rsa_key
    end

    def x509_certificate
      cert_wrapper.x509_cert
    end

    protected

    def cert_wrapper
      @_cert_wrapper ||= Certificate.create(@certificate, @password)
    end
  end

  class StoreAuthOptions < AuthOptions
  end

  class RequestAuthOptions < AuthOptions
  end
end
