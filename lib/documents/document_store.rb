require "securerandom"
require "database/operation_executor"
require "documents/conventions"
require "requests/request_executor"
require "database/exceptions"
require "documents/hilo"
require "documents/document_session"
require "auth/auth_options"

module RavenDB
  class Configuration
    attr_accessor :database, :urls, :auth_options

    def initialize
      @database = nil
      @urls = nil
      @auth_options = nil
    end
  end

  class DocumentStore
    def initialize(url_or_urls = nil, database = nil, auth_options = nil)
      @_urls = []
      @_conventions = nil
      @_request_executors = nil
      @_operations = nil
      @_maintenance = nil
      @_initialized = false
      @_database = database
      @_disposed = false
      @_auth_options = auth_options
      set_urls(url_or_urls)
    end

    def self.create(url_or_urls, database, auth_options = nil)
      new(url_or_urls, database, auth_options)
    end

    def configure
      unless @_initialized
        config = Configuration.new

        if block_given?
          yield(config)
        end

        unless config.database.nil?
          @_database = config.database
        end

        unless config.auth_options.nil?
          @_auth_options = config.auth_options
        end

        unless config.urls.nil?
          set_urls(config.urls)
        end

        unless @_database
          raise "Default database isn't set."
        end

        unless @_auth_options.nil? || @_auth_options.is_a?(StoreAuthOptions)
          raise ArgumentError,
                "Invalid auth options provided"
        end

        if @_auth_options.nil? && @_urls.any? { |url| url.downcase.start_with?("https") }
          raise NotSupportedException, "Access to secured servers requires StoreAuthOptions to be set"
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

    def auth_options
      @_auth_options
    end

    def operations
      assert_configure
      @_operations ||= OperationExecutor.new(self, @_database)
    end

    def maintenance
      assert_configure
      @_maintenance ||= AdminOperationExecutor.new(self, @_database)
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

      session_database ||= database
      request_executor = nil

      if session_options.key?(:request_executor)
        request_executor = session_options[:request_executor]
      end

      if request_executor.nil? || (request_executor.initial_database != session_database)
        request_executor = get_request_executor(session_database)
      end

      session = DocumentSession.new(session_database, self, SecureRandom.uuid, request_executor)

      if block_given?
        yield(session)
      end

      session
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

      unless @_request_executors.key?(for_single_node)
        @_request_executors[for_single_node] = {}
      end

      unless @_request_executors[for_single_node].key?(db_name)
        @_request_executors[for_single_node][db_name] = create_request_executor(db_name, for_single_node)
      end

      @_request_executors[for_single_node][db_name]
    end

    def dispose
      unless @_disposed
        @_disposed = true

        assert_configure
        begin
          @_generator.return_unused_range
        rescue StandardError
          nil
        end
        maintenance.server.dispose

        if @_request_executors.is_a?(Hash)
          @_request_executors.each_value do |executors|
            executors.each_value { |executor| executor.dispose }
          end
        end
      end
    end

    protected

    def set_urls(url_or_urls)
      unless url_or_urls.nil?
        @_urls = url_or_urls

        unless url_or_urls.is_a?(Array)
          @_urls = [@_urls]
        end
      end
    end

    def assert_configure
      unless @_initialized
        raise "You cannot open a session or access the database commands"\
  " before initializing the document store. Did you forget calling configure ?"
      end
    end

    def create_request_executor(database = nil, for_single_node = nil)
      db_name = database || @_database
      auth = nil

      unless @_auth_options.nil?
        auth = RequestAuthOptions.new(
          @_auth_options.certificate,
          @_auth_options.password
        )
      end

      if for_single_node
        RequestExecutor.create_for_single_node(single_node_url, db_name, auth)
      else
        RequestExecutor.create(urls, db_name, auth)
      end
    end
  end
end
