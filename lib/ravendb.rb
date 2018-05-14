require_relative "./version.rb"
require "logger"
require "documents/document_store"

module RavenDB
  # Returns an initially-unconfigured instance of the document store.
  # @return [DocumentStore] an instance of the store
  #
  # @example Configuring and using the document store
  #   RavenDB.store.configure do |config|
  #     config.urls = ["http://4.live-test.ravendb.net"]
  #     config.default_database = 'NortWindTest'
  #   end
  #
  #   RavenDB.store.open_session do |session|
  #     session.store(Product.new("Products/1", "Test Product"))
  #     session.save_changes
  #   end
  #
  def self.store
    @store ||= DocumentStore.new
  end

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new(STDERR).tap do |log|
        log.progname = name
      end
    end
  end
end
