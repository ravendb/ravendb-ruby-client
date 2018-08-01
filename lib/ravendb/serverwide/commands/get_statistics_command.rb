module RavenDB
  class GetStatisticsCommand < RavenCommand
    def initialize(check_for_failures: false, debug_tag: false)
      super()
      @check_for_failures = check_for_failures
      @debug_tag = debug_tag
    end

    def create_request(server_node)
      assert_node(server_node)

      end_point = "/databases/#{server_node.database}/stats?"
      end_point += @debug_tag.to_s if @debug_tag
      end_point += "&failure=check" if @check_for_failures

      Net::HTTP::Get.new(end_point)
    end

    def read_request?
      true
    end

    def parse_response(json, from_cache:, conventions: nil)
      @mapper.read_value(json, DatabaseStatistics, nested: {size_on_disk: Size, indexes: IndexInformation}, conventions: conventions)
    end
  end

  class DatabaseStatistics
    attr_accessor :count_of_indexes
    attr_accessor :count_of_documents
    attr_accessor :count_of_revision_documents
    attr_accessor :count_of_tombstones
    attr_accessor :count_of_documents_conflicts
    attr_accessor :count_of_conflicts
    attr_accessor :count_of_attachments
    attr_accessor :count_of_unique_attachments
    attr_accessor :database_change_vector
    attr_accessor :database_id
    attr_accessor :number_of_transaction_merger_queue_operations
    attr_accessor :is64_bit
    attr_accessor :pager
    attr_accessor :last_doc_etag
    attr_accessor :last_indexing_time
    attr_accessor :size_on_disk
    attr_accessor :indexes
  end

  class Size
    attr_accessor :size_in_bytes
    attr_accessor :humane_size
  end

  class IndexInformation
    attr_accessor :name
    attr_accessor :state
    attr_accessor :lock_mode
    attr_accessor :priority
    attr_accessor :type
    attr_accessor :last_indexing_time

    def stale?
      @is_stale
    end
  end
end
