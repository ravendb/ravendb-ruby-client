require 'securerandom'
require 'database/operation_executor'
require 'documents/conventions'
require 'requests/request_executor'
require 'database/exceptions'
require 'documents/hilo'
require 'documents/document_session'

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

        if block_given?
          yield(config)
        end

        if config.default_database
          @_database = config.default_database
        end

        if config.urls
          set_urls(config.urls)
        end

        if !@_database
          raise InvalidOperationException, "Default database isn't set."
        end

        if @_urls.any? {|url| url.downcase.start_with?('https') }
          raise NotSupportedException, "Access to secured servers is not yet supported in Ruby client"
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
      assert_configure
      @_operations ||= OperationExecutor.new(self, @_database)
    end

    def admin
      assert_configure
      @_admin ||= AdminOperationExecutor.new(self, @_database)      
    end

    def conventions
      @_conventions ||= DocumentConventions.new
    end

    def open_session(database_name = nil, options = nil)
      assert_configure

      session_database = database_name
      session_options = options || {}

      if database_name.is_a?(Hash)
        session_options = database_name

        if session_options.key?(:database)
          session_database = session_options[:database]
        end
      end

      session_database = session_database || database
      request_executor = nil

      if session_options.key?(:request_executor)
        request_executor = session_options[:request_executor]
      end

      if request_executor.nil? || (request_executor.initial_database != session_database)
        request_executor = get_request_executor(session_database)
      end

      DocumentSession.new(session_database, self, SecureRandom.uuid, request_executor)
    end

    def generate_id(tag = nil, database = nil)
      assert_configure

      if tag.nil?
        return SecureRandom.uuid
      end

      @_generator.generate_document_id(tag, database)
    end

    def get_request_executor(database = nil)
      assert_configure

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

    def dispose
      assert_configure
      @_generator.return_unused_range rescue nil
      admin.server.dispose

      if @_request_executors.is_a?(Hash)
        @_request_executors.each_value do |executors|
          executors.each_value {|executor| executor.dispose}
        end
      end
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

    def assert_configure
      if !@_initialized
        raise InvalidOperationException, "You cannot open a session or access the database commands"\
  " before initializing the document store. Did you forget calling configure ?"
      end
    end

    def create_request_executor(database = nil, for_single_node = nil)
      db_name = database || @_database
      
      (true == for_single_node) ? 
        RequestExecutor.create_for_single_node(single_node_url, db_name) :
        RequestExecutor.create(urls, db_name)
    end
  end  
end