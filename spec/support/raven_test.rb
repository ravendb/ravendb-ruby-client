require "rainbow"

module RavenTest
  DEFAULT_URL = ENV["URL"] || "http://localhost:8080"
  DEFAULT_DATABASE = ENV["DATABASE"] || "NorthWindTest"
  CERT_FILE = ENV["CERTIFICATE"]
  CERT_PASSPHRASE = ENV["PASSPHRASE"]

  CONSUME_LOG = ENV["LOG"] != "1"

  def self.setup(context, _example)
    context.instance_eval do
      if CONSUME_LOG
        @_log = StringIO.new
        @_logger = Logger.new(@_log)
        RavenDB.logger = @_logger
      end
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

  def self.teardown(context, example)
    context.instance_eval do
      @_store.dispose
      @_store = nil
      @_current_database = nil
      if CONSUME_LOG
        if example.exception
          puts
          puts
          puts Rainbow(example.full_description).bold.red + Rainbow(" (#{example.location}) failed. Output:").red
          puts @_log.string
          puts
        end
        RavenDB.logger = nil
      end
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
