require 'securerandom'
require 'database/operation_executor'
require 'documents/conventions'
require 'requests/request_executor'
require 'database/exceptions'
require 'documents/hilo'

module RavenDB
  class Configuration
    attr_accessor :default_database, :urls
  end

  class DocumentStore
    def initialize(url_or_urls = nil, default_database = nil)
      @_urls = []  
      @_conventions = nil
      @_request_executors = nil
      @_operations = nil
      @_admin = nil
      @_initialized = false
      @_database = default_database
      set_urls(url_or_urls)
    end

    def self.create(url_or_urls, default_database)
      self.new(url_or_urls, default_database)
    end

    def configure
      if !@_initialized
        config = Configuration.new

        yield(config)

        if config.default_database
          @_database = config.default_database
        end

        if config.urls
          set_urls(config.urls)
        end

        if !@_database
          raise InvalidOperationException, "Default database isn't set."
        end

        @_generator = HiloMultiDatabaseIdGenerator.new(self)
        @_initialized = true
      end

      self
    end  

    def database
      @_database
    end

    def urls
      @_urls
    end

    def single_node_url
      @_urls.first
    end

    def operations
      @_operations ||= OperationExecutor.new(self, @_database)
    end

    def admin
      @_admin ||= AdminOperationExecutor.new(self, @_database)      
    end

    def get_request_executor(database = nil)
      @_request_executors ||= {}
      db_name = database || @_database
      for_single_node = conventions.disable_topology_updates

      if !@_request_executors.key?(for_single_node)
        @_request_executors[for_single_node] = {}
      end  

      if !@_request_executors[for_single_node].key?(db_name)
        @_request_executors[for_single_node][db_name] = create_request_executor(db_name, for_single_node)
      end    

      @_request_executors[for_single_node][db_name]
    end

    def conventions
      @_conventions ||= DocumentConventions.new
    end

    def generate_id(tag = nil, database = nil)
      if tag.nil?
        return SecureRandom.uuid
      end

      @_generator.generate_document_id(tag, database)
    end

    protected 
    def set_urls(url_or_urls)
      if !url_or_urls.nil?
        @_urls = url_or_urls

        if !url_or_urls.is_a?(Array)
          @_urls = [@_urls]
        end  
      end  
    end  

    def assert_initialize()
      if !@_initialized
        raise InvalidOperationException, "You cannot open a session or access the _database commands"\
  "before initializing the document store. Did you forget calling initialize()?"
      end
    end

    def create_request_executor(database = nil, for_single_node = nil)
      db_name = database || @_database
      
      (true == for_single_node) ? 
        RequestExecutor.create_for_single_node(singleNodeUrl, db_name) :
        RequestExecutor.create(urls, db_name)
    end
  end  
end