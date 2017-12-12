require 'io'
require 'openssl'

module RavenDB
  class Certificate
    attr_reader :x509

    def self.create(source)
      if source.is_a?(OpenSSL::X509::Certificate)
        self.new(source)
      elsif File.exists?(source)
        self.from_file(source)
      else
        self.from_string(source)
      end
    end

    def self.from_string(pem)
      unless pem.include?('CERTIFICATE')
        pem = "-----BEGIN CERTIFICATE-----\n#{pem}-----END CERTIFICATE-----\n"
      end

      OpenSSL::X509::Certificate.new(pem)
    end

    def self.from_file(path)
      self.from_string(File::read(path));
    end

    def initialize(x509_certificate)
      raise ArgumentError,
        "Invalid x509 certificate provided" unless
        x509_certificate.is_a?(OpenSSL::X509::Certificate)

      @x509 = x509_certificate
    end
  end
end