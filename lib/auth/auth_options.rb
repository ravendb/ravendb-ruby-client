require 'auth/certificate'

module RavenDB
  class AuthOptions
    attr_reader :certificate, :password, :root

    def initialize(certificate, password = nil, root = nil)
      @certificate = certificate
      @password = password
      @root = root
      @_cert_wrapper = nil
    end

    def get_rsa_key
      get_cert_wrapper.rsa_key
    end

    def get_x509_certificate
      get_cert_wrapper.x509_cert
    end

    protected
    def get_cert_wrapper
      @_cert_wrapper ||= Certificate
        .create(@certificate, @password)
    end
  end

  class StoreAuthOptions < AuthOptions

  end

  class RequestAuthOptions < AuthOptions

  end
end