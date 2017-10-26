require 'net/http'

module RavenDB
  class RavenException < StandardError
  end

  class ExceptionsFactory
    def self.create(type_or_message, message = "")
      exception_ctor = RavenException
      exception_message = type_or_message

      if type_or_message && message
        exception_message = message

        begin
          exception_ctor = Object.const_get("RavenDB::#{type_or_message}")
        rescue
          exception_ctor = RavenException
        end
      end

      exception_ctor.new(message)
    end

    def self.create_from(json_or_response)
      if json_or_response.is_a? Net::HTTPResponse
        response = json_or_response
        json = response.json

        if json && (response.code.to_i >= 400)
          return create_from(json)
        end
      else
        json = json_or_response

        if json && json.key?("Type") && json.key?("Error")
          type = json["Type"]

          if type && json["Error"]
            return create(type.split(".").last, json["Error"])
          end
        end
      end

      return nil
    end

    def self.raise_exception(type_or_message, message = "")
      exception = create(type_or_message, message)

      if !exception.nil?
        raise exception
      end
    end   

    def self.raise_from(json_or_response)
      exception = create_from(json_or_response)

      if !exception.nil?
        raise exception
      end
    end
  end  

  class InvalidOperationException < RavenException 
  end
  class ErrorResponseException < RavenException 
  end
  class DocumentDoesNotExistsException < RavenException 
  end
  class NonUniqueObjectException < RavenException 
  end
  class ConcurrencyException < RavenException 
  end
  class ArgumentNullException < RavenException 
  end
  class ArgumentOutOfRangeException < RavenException 
  end
  class DatabaseDoesNotExistException < RavenException 
  end
  class AuthorizationException < RavenException 
  end
  class IndexDoesNotExistException < RavenException 
  end
  class DatabaseLoadTimeoutException < RavenException 
  end
  class AuthenticationException < RavenException 
  end
  class BadRequestException < RavenException 
  end
  class BulkInsertAbortedException < RavenException 
  end
  class BulkInsertProtocolViolationException < RavenException
  end
  class IndexCompilationException < RavenException
  end
  class TransformerCompilationException < RavenException 
  end
  class DocumentConflictException < RavenException 
  end
  class DocumentDoesNotExistException < RavenException 
  end
  class DocumentParseException < RavenException 
  end
  class IndexInvalidException < RavenException 
  end
  class IndexOrTransformerAlreadyExistException < RavenException 
  end
  class JavaScriptException < RavenException 
  end
  class JavaScriptParseException < RavenException 
  end
  class SubscriptionClosedException < RavenException 
  end
  class SubscriptionDoesNotBelongToNodeException < RavenException 
  end
  class SubscriptionDoesNotExistException < RavenException 
  end
  class SubscriptionException < RavenException 
  end
  class SubscriptionInUseException < RavenException 
  end
  class TransformerDoesNotExistException < RavenException 
  end
  class VersioningDisabledException < RavenException 
  end
  class AllTopologyNodesDownException < RavenException
  end
  class BadResponseException < RavenException 
  end
  class ChangeProcessingException < RavenException 
  end
  class CommandExecutionException < RavenException 
  end
  class NoLeaderException < RavenException 
  end
  class CompilationException < RavenException 
  end
  class ConflictException < RavenException 
  end
  class DatabaseConcurrentLoadTimeoutException < RavenException 
  end
  class DatabaseDisabledException < RavenException 
  end
  class DatabaseLoadFailureException < RavenException 
  end
  class DatabaseNotFoundException < RavenException 
  end
  class NotSupportedOsException < RavenException 
  end
  class SecurityException < RavenException 
  end
  class ServerLoadFailureException < RavenException 
  end
  class UnsuccessfulRequestException < RavenException 
  end
  class CriticalIndexingException < RavenException 
  end
  class IndexAnalyzerException < RavenException 
  end
  class IndexCorruptionException < RavenException 
  end
  class IndexOpenException < RavenException 
  end
  class IndexWriteException < RavenException 
  end
  class IndexWriterCreationException < RavenException 
  end
  class StorageException < RavenException 
  end
  class StreamDisposedException < RavenException 
  end
  class LowMemoryException < RavenException 
  end
  class IncorrectDllException < RavenException 
  end
  class DiskFullException < RavenException 
  end
  class InvalidJournalFlushRequestException < RavenException 
  end
  class QuotaException < RavenException 
  end
  class VoronUnrecoverableErrorException < RavenException 
  end
  class NonDurableFileSystemException < RavenException 
  end
  class AggregateException < RavenException 
  end
end  