require 'io'
require 'openssl'

module RavenDB
  class Certificate
    attr_reader :rsa_key

    def self.create(source, password = nil)
      if source.is_a?(OpenSSL::PKey::RSA)
        self.new(source)
      elsif File.exists?(source)
        self.from_file(source, password)
      else
        self.from_string(source, password)
      end
    end

    def self.from_string(pem, password = nil)
      OpenSSL::PKey::RSA.new(pem, password)
    end

    def self.from_file(path, password = nil)
      self.from_string(File::read(path), password);
    end

    def initialize(rsa_key)
      raise ArgumentError,
        "Invalid RSA key provided" unless
        rsa_key.is_a?(OpenSSL::PKey::RSA)

      @rsa_key = rsa_key
    end
  end
end