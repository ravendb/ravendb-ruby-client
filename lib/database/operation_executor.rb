require 'time'
require 'net/http'
require 'database/operations'
require 'database/commands'
require 'database/exceptions'
require 'constants/database'
require 'constants/documents'
require 'requests/request_executor'

module RavenDB
  class OperationAwaiter
    @request_executor = nil
    @operation_id = nil
    @timeout = nil

    def initialize(request_executor, operation_id, timeout = nil)
      @request_executor = request_executor
      @operation_id = operationId
      @timeout = timeout
    end

    def wait_for_completion
      status_result = fetch_operation_status

      return on_next(status_result)
    end

    protected
    def fetch_operation_status
      start_time = Time.now.to_f
      status_command = GetOperationStateCommand.new(@operationId)

      begin
        response = @request_executor.execute(status_command)
        
        if @timeout && ((Time.now.to_f - start_time) > @timeout)
          return {
            "status" => OperationStatus::Faulted,
            "exception" => DatabaseLoadTimeoutException.new('The operation did not finish before the timeout end')
          }
        end
        
        case response["Status"]
          when OperationStatus::Completed
            return {
              "status" => response["Status"],
              "response" => response
            }
          when OperationStatus::Faulted
            return {
              "status" => response["Status"],
              "exception" => InvalidOperationException.new(response["Result"]["Error"])
            }  
          else
            return {
              "status" => OperationStatus::Running
            }  
        end
      rescue => exception
        return {
          "status" => OperationStatus::Faulted,
          "exception" => exception
        }
      end  
    end  

    protected 
    def on_next(result)
      case result["status"]
        when OperationStatus::Completed
          return result["response"]
        when OperationStatus::Faulted
          raise result.exception        
        else
          sleep .5
          return on_next(fetch_operation_status)
      end
    end
  end

  class AbstractOperationExecutor
    @store = nil
    @_request_executor = nil
    
    protected 
    def request_executor_factory
      raise NotImplementedError, 'You should implement request_executor_factory method'
    end  

    protected 
    def request_executor
      if (!@_request_executor) {
        @_request_executor = request_executor_factory
      }

      return @_request_executor
    end

    def initialize(store)
      @store = store
    end

    def send(operation)
      command = nil
      store = @store
      executor = request_executor
      conventions = store.conventions
      error_message = 'Invalid object passed as an operation'      
      
      if operation.is_a?(AbstractOperation)
        begin
          command = operation.is_a?(Operation)
            ? operation.getCommand(conventions, store)
            : operation.getCommand(conventions);   
        rescue => exception
          errorMessage = "Can't instantiate command required for run operation: #{exception.message}";
        end      
      end  
      
      if !command
        raise InvalidOperationException, errorMessage
      end

      result = executor.execute(command)

      return set_response(operation, command, result)
    end

    protected
    def set_response(operation, command, response)    
      return response
    end
  end

  class AbstractDatabaseOperationExecutor < AbstractOperationExecutor
    @database = nil
    @executors_by_database = {}
    
    def initialize(store, database = nil)
      super(store)
      @database = database
    end

    def for_database(database)
      if database === @database
        return self
      end

      if !@executors_by_database.key?(database)
        @executors_by_database[database] = self.class.new(@store, database)
      end

      return @executors_by_database[database]
    end

    protected
    def request_executor_factory
      return @store.get_request_executor(@database)
    end
  }

  class OperationExecutor < AbstractDatabaseOperationExecutor
    protected 
    def set_response(operation, command, response)
      store = @store
      json = response
      conventions = store.conventions

      if operation.is_a?(AwaitableOperation)
        awaiter = OperationAwaiter.new(@request_executor, json["OperationId"])

        return awaiter.wait_for_completion
      }

      if operation.is_a?(PatchResultOperation)
        patchResult = nil

        case command.server_response
          when Net::HttpNotModified
            patchResult = {
              "Status" => PatchStatuses.NotModified
            }
          case Net::HttpNotFound
            patchResult = {
              "Status" => PatchStatuses.DocumentDoesNotExist
            }
          else
            patchResult = {
              "Status" => json["Status"],
              "Document" => conventions.convert_to_document(json["ModifiedDocument"])
            }          
        }

        response = patchResult
      end

      return super(operation, command, response)
    end
  end

  class ServerOperationExecutor < AbstractOperationExecutor
    protected
    def request_executor_factory
      store = @store;
      conventions = store.conventions

      return conventions.DisableTopologyUpdates
        ? ClusterRequestExecutor.create_for_single_node(store.single_node_url)
        : ClusterRequestExecutor.create(store.urls)
    end

    def send(operation)
      raise InvalidOperationException, 'Invalid operation passed. It should be derived from ServerOperation' unless operation.is_a?(ServerOperation)

      return super(operation)
    end
  end

  export class AdminOperationExecutor extends AbstractDatabaseOperationExecutor {
    @_server = nil

    def server
      if !@_server
        @_server = ServerOperationExecutor.new(@store)
      end

      return @_server
    end

    def send(operation)
      raise InvalidOperationException, 'Invalid operation passed. It should be derived from AdminOperation' unless operation.is_a?(AdminOperation)
      
      return super(operation)
    end
  end
end  