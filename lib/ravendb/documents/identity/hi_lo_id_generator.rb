module RavenDB
  class HiLoIdGenerator
    def initialize(tag, store, db_name, identity_parts_separator)
      @_store = store
      @_tag = tag
      @_db_name = db_name
      @_identity_parts_separator = identity_parts_separator
      @_range = RangeValue.new(1, 0)
      @mutex = Mutex.new
    end

    def document_id_from_id(next_id)
      "#{@prefix}#{next_id}-#{@server_tag}"
    end

    def range
      @_range
    end

    def range=(range)
      self._range = range
    end

    def generate_document_id(_entity)
      document_id_from_id(next_id)
    end

    def next_id
      loop do
        range = @_range
        id = range.current.increment
        return id if id <= range.max
        @mutex.synchronize do
          id = range.current.value
          return id if id <= range.max
          next_range
        end
      end
    end

    def next_range
      hilo_command = NextHiLoCommand.new(@_tag, @_last_batch_size, @_last_range_date, @_identity_parts_separator, @_range.max)
      re = @_store.request_executor
      re.execute(hilo_command)
      @prefix = hilo_command.result.prefix
      @server_tag = hilo_command.result.server_tag
      @_last_range_date = hilo_command.result.last_range_at
      @_last_batch_size = hilo_command.result.last_size
      @_range = RangeValue.new(hilo_command.result.low, hilo_command.result.high)
    end

    def return_unused_range
      return_command = HiLoReturnCommand.new(@_tag, @_range.current.get, @_range.max)
      re = @_store.request_executor(@_db_name)
      re.execute(return_command)
    end

    class RangeValue
      attr_accessor :min
      attr_accessor :max
      attr_accessor :current

      def initialize(min, max)
        @min = min
        @max = max
        @current = Concurrent::AtomicFixnum.new(min - 1)
      end
    end
  end
end
