module RavenDB
  class ConcurrentHashMap
    def initialize
      @data = Concurrent::Hash.new
      @self_lock = Mutex.new
    end

    def synchronized
      @self_lock.synchronize do
        yield
      end
    end

    def put_if_absent(index, value)
      compute_if_absent(index) { value }
    end

    def compute_if_absent(index)
      synchronized do
        @data[index] = yield unless @data.key?(index)
        @data[index]
      end
    end
  end
end
