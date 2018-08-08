module RavenDB
  class BatchOptions
    attr_accessor :wait_for_replicas
    attr_accessor :number_of_replicas_to_wait_for
    attr_accessor :wait_for_replicas_timeout
    attr_accessor :majority
    attr_accessor :throw_on_timeout_in_wait_for_replicas
    attr_accessor :wait_for_indexes
    attr_accessor :wait_for_indexes_timeout
    attr_accessor :throw_on_timeout_in_wait_for_indexes
    attr_accessor :wait_for_specific_indexes

    def wait_for_replicas?
      wait_for_replicas
    end

    def majority?
      majority
    end

    def throw_on_timeout_in_wait_for_replicas?
      throw_on_timeout_in_wait_for_replicas
    end

    def wait_for_indexes?
      wait_for_indexes
    end

    def throw_on_timeout_in_wait_for_indexes?
      throw_on_timeout_in_wait_for_indexes
    end
  end
end
