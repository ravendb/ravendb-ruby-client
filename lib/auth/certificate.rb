require "openssl"

module RavenDB
  class Certificate
    attr_reader :rsa_key, :x509_cert

    def initialize(pem, password)
      @rsa_key = OpenSSL::PKey::RSA.new(pem, password)
      @x509_cert = OpenSSL::X509::Certificate.new(pem)
    end
  end
end
