require 'auth/certificate'

module RavenDB
  class RequestOptions
    attr_reader :certificate, :password

    def initialize(certificate, password)
      raise ArgumentError,
        "Invalid certificate provided" unless
          certificate.is_a?(Certificate)

      @certificate = certificate
      @password = password
    end
  end

  class DocumentStoreOptions < RequestOptions

  end

  class RequestExecutorOptions < RequestOptions

  end
end