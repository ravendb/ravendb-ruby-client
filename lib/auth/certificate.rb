require 'openssl'

module RavenDB
  class Certificate
    attr_reader :rsa_key, :x509_cert

    def self.create(source, password = nil)
      if File.exist?(source)
        self.from_file(source, password)
      else
        self.from_string(source, password)
      end
    end

    def self.from_string(pem, password = nil)
      self.new(pem, password)
    end

    def self.from_file(path, password = nil)
      self.from_string(File::read(path), password)
    end

    def initialize(pem, password)
      @rsa_key = OpenSSL::PKey::RSA.new(pem, password)
      @x509_cert = OpenSSL::X509::Certificate.new(pem)
    end
  end
end