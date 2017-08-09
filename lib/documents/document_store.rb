require 'database/operations_executor'
require 'documents/conventions'
require 'requests/request_executor'
require 'database/exceptions'

module RavenDB
  class DocumentStore
    @_initialized = false
    @_urls = []  
    @_database = nil
    @_conventions = nil
    @_request_executors = nil
    @_operations = nil
    @_admin = nil

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
      if !@_operations
        @_operations = OperationExecutor.new(self, @_database)
      end

      return @_operations;
    end

    def admin
      if !@_admin
        @_admin = AdminOperationExecutor.new(self, @_database)      
      end

      return @_admin
    end

    def get_request_executor(database = nil)
      db_name = database || @_database
      for_single_node = conventions.DisableTopologyUpdates

      if !@_request_executors
        @_request_executors = {}
      end
      
      if !@_request_executors.key?(for_single_node)
        @_request_executors[for_single_node] = {}
      end  

      if !@_request_executors[for_single_node].key?(db_name)
        @_request_executors[for_single_node][db_name] = create_request_executor(db_name, for_single_node)
      end    

      return @_request_executors[for_single_node][db_name]
    end

    def conventions
      if !@_conventions
        @_conventions = DocumentConventions.new
      end

      return @_conventions;
    end

    def initialize(url_or_urls = nil, default_database = nil)
      @_initialized = false
      @_database = default_database
      set_urls(url_or_urls)
    end

    def self.create(url_or_urls, default_database)
      return new self(url_or_urls, default_database)
    end

    def configure(configure_callback)
      config = {}

      if configure_callback
        configure_callback.call(configure_callback)
      end  

      if config.default_database
        @_database = config.default_database
      end

      if config.urls
        set_urls(config.urls)
      end

      if !@_initialized
        if !this._database
          raise InvalidOperationException, "Default database isn't set."
        end
    end   

      @_initialized = true
    end  

    protected 
    def set_urls(url_or_urls)
      @_urls = url_or_urls

      if !url_or_urls.is_a?(Array)
        @_urls = [@_urls]
      end  
    end  

    protected
    def assert_initialize()
      if !@_initialized
        raise InvalidOperationException, "You cannot open a session or access the _database commands"\
  "before initializing the document store. Did you forget calling initialize()?"
      end
    end

    protected 
    def create_request_executor(database = nil, for_single_node = nil)
      db_name = database || @_database;
      executor = (true === for_single_node)
        ? RequestExecutor.create_for_single_node(singleNodeUrl, db_name)
        : RequestExecutor.create(@urls, db_name);
      
      return executor
    end
  end  
end