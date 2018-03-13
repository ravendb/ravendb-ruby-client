module RavenTest
  DEFAULT_URL = ENV["URL"] || "http://localhost:8080"
  DEFAULT_DATABASE = ENV["DATABASE"] || "NorthWindTest"
  CERT_FILE = ENV["CERTIFICATE"] || nil
  CERT_PASSPHRASE = ENV["PASSPHRASE"] || nil

  def self.setup(context)
    context.instance_eval do
      @_current_database = "#{DEFAULT_DATABASE}__#{SecureRandom.uuid}"
      @_store = RavenDB::DocumentStore.new([DEFAULT_URL], @_current_database)
      @_store.configure do |config|
        unless CERT_FILE.nil?
          config.auth_options = RavenDB::StoreAuthOptions.new(File.read(CERT_FILE), CERT_PASSPHRASE)
        end
      end

      @_store.conventions.disable_topology_updates = true
    end
  end

  def self.teardown(context)
    context.instance_eval do
      @_store.dispose
      @_store = nil
      @_current_database = nil
    end
  end
end

module RavenTestHelpers
  def store
    @_store
  end

  def current_database
    @_current_database
  end

  def default_url
    RavenTest::DEFAULT_URL
  end
end
