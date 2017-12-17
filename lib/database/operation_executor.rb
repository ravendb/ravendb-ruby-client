require 'time'
require 'net/http'
require 'database/operations'
require 'database/commands'
require 'database/exceptions'
require 'constants/database'
require 'constants/documents'
require 'requests/request_executor'
require 'auth/auth_options'

module RavenDB
  class OperationAwaiter
    def initialize(request_executor, operation_id, timeout = nil)
      @request_executor = request_executor || nil
      @operation_id = operation_id || nil
      @timeout = timeout
    end

    def wait_for_completion
      status_result = fetch_operation_status

      on_next(status_result)
    end

    protected
    def fetch_operation_status
      start_time = Time.now.to_f
      status_command = GetOperationStateCommand.new(@operation_id)

      begin
        response = @request_executor.execute(status_command)
        
        if @timeout && ((Time.now.to_f - start_time) > @timeout)
          return {
            :status => OperationStatus::Faulted,
            :exception => DatabaseLoadTimeoutException.new('The operation did not finish before the timeout end')
          }
        end
        
        case response["Status"]
        when OperationStatus::Completed
          return {
            :status => response["Status"],
            :response => response
          }
        when OperationStatus::Faulted
          exception = ExceptionsFactory.create_from(response["Result"])

          if exception.nil?
            exception = RuntimeError.new(response["Result"]["Error"])
          end

          return {
            :status => response["Status"],
            :exception => exception
          }  
        else
          return {
            :status => OperationStatus::Running
          }  
        end

      rescue => exception
        return {
          :status => OperationStatus::Faulted,
          :exception => exception
        }
      end  
    end  

    def on_next(result)
      case result[:status]
      when OperationStatus::Completed
        return result[:response]
      when OperationStatus::Faulted
        raise result[:exception]
      else
        sleep 0.5
        return on_next(fetch_operation_status)
      end
    end
  end

  class AbstractOperationExecutor
    def initialize(store)
      @store = store
      @_request_executor = nil
    end
    
    def send(operation)
      command = nil
      store = @store
      executor = request_executor
      conventions = store.conventions
      error_message = 'Invalid object passed as an operation'      
      
      if operation.is_a?(AbstractOperation)
        begin
          command = operation.is_a?(Operation) ? 
            operation.get_command(conventions, store) : 
            operation.get_command(conventions)
        rescue => exception
          error_message = "Can't instantiate command required for run operation: #{exception.message}"
        end      
      end  
      
      if !command
        raise RuntimeError, error_message
      end

      result = executor.execute(command)

      set_response(operation, command, result)
    end

    protected
    def set_response(operation, command, response)    
      response
    end

    def request_executor_factory
      raise NotImplementedError, 'You should implement request_executor_factory method'
    end  

    def request_executor
      @_request_executor ||= request_executor_factory
    end
  end

  class AbstractDatabaseOperationExecutor < AbstractOperationExecutor
    def initialize(store, database = nil)
      super(store)
      @database = database
      @executors_by_database = {}
    end

    def for_database(database)
      if database == @database
        return self
      end

      if !@executors_by_database.key?(database)
        @executors_by_database[database] = self.class.new(@store, database)
      end

      @executors_by_database[database]
    end

    protected
    def request_executor_factory
      @store.get_request_executor(@database)
    end
  end

  class OperationExecutor < AbstractDatabaseOperationExecutor
    protected 
    def set_response(operation, command, response)
      store = @store
      json = response
      conventions = store.conventions

      if operation.is_a?(AwaitableOperation)
        awaiter = OperationAwaiter.new(request_executor, json["OperationId"])

        return awaiter.wait_for_completion
      end

      if operation.is_a?(PatchResultOperation)
        patch_result = nil

        case command.server_response
        when Net::HTTPNotModified
          patch_result = {
            :Status => PatchStatus::NotModified
          }
        when Net::HTTPNotFound
          patch_result = {
            :Status => PatchStatus::DocumentDoesNotExist
          }
        else
          document = nil
          conversion_result = conventions.convert_to_document(json["ModifiedDocument"])

          if conversion_result
            document = conversion_result[:document]
          end

          patch_result = {
            :Status => json["Status"],
            :Document => document
          }          
        end

        response = patch_result
      end

      super(operation, command, response)
    end    
  end

  class ServerOperationExecutor < AbstractOperationExecutor
    def send(operation)
      raise RuntimeError, 'Invalid operation passed. It should be derived from ServerOperation' unless operation.is_a?(ServerOperation)

      super(operation)
    end

    def dispose
      request_executor.dispose
    end

    protected
    def request_executor_factory
      auth = nil
      store = @store
      conventions = store.conventions

      unless store.auth_options.nil?
        auth = RequestAuthOptions.new(
          store.auth_options.certificate,
          store.auth_options.password,
          store.auth_options.root
        )
      end

      conventions.disable_topology_updates ?
       ClusterRequestExecutor.create_for_single_node(store.single_node_url, nil, auth) :
       ClusterRequestExecutor.create(store.urls, nil, auth)
    end    
  end

  class AdminOperationExecutor < AbstractDatabaseOperationExecutor
    def initialize(store, database = nil)
      super(store, database)
      @_server = nil
    end  

    def server
      @_server ||= ServerOperationExecutor.new(@store)
    end

    def send(operation)
      raise RuntimeError, 'Invalid operation passed. It should be derived from AdminOperation' unless operation.is_a?(AdminOperation)
      
      super(operation)
    end
  end
end  