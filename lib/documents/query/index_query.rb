module RavenDB
  class IndexQuery
    DefaultTimeout = 15 * 1000
    DefaultPageSize = 2 ** 31 - 1

    attr_accessor :start, :page_size
    attr_reader :query, :query_parameters, :wait_for_non_stale_results,
                :wait_for_non_stale_results_as_of_now, :wait_for_non_stale_results_timeout

    def initialize(query = "", query_parameters = {}, page_size = DefaultPageSize, skipped_results = 0, options = {})
      @query = query
      @query_parameters = query_parameters || {}
      @page_size = page_size || DefaultPageSize
      @start = skipped_results || 0
      @cut_off_etag = options[:cut_off_etag] || nil
      @wait_for_non_stale_results = options[:wait_for_non_stale_results] || false
      @wait_for_non_stale_results_as_of_now = options[:wait_for_non_stale_results_as_of_now] || false
      @wait_for_non_stale_results_timeout = options[:wait_for_non_stale_results_timeout] || nil

      if !@page_size.is_a?(Numeric)
        @page_size = DefaultPageSize
      end

      if (@wait_for_non_stale_results ||
          @wait_for_non_stale_results_as_of_now) &&
          !@wait_for_non_stale_results_timeout

        @wait_for_non_stale_results_timeout = DefaultTimeout
      end
    end

    def query_hash
      buffer = "#{@query}#{@page_size}#{@start}"
      buffer = buffer + (@wait_for_non_stale_results ? "1" : "0")
      buffer = buffer + (@wait_for_non_stale_results_as_of_now ? "1" : "0")

      if @wait_for_non_stale_results
        buffer = buffer + "#{@wait_for_non_stale_results_timeout}"
      end

      Digest::SHA256.hexdigest(buffer)
    end

    def to_json
      json = {
        "Query" => @query,
        "QueryParameters" => @query_parameters,
      }

      if !@start.nil?
        json["Start"] = @start
      end

      if !@page_size.nil?
        json["PageSize"] = @page_size
      end

      if !@cut_off_etag.nil?
        json["CutoffEtag"] = @cut_off_etag
      end

      if !@wait_for_non_stale_results.nil?
        json["WaitForNonStaleResults"] = true
      end

      if !@wait_for_non_stale_results_as_of_now.nil?
        json["WaitForNonStaleResultsAsOfNow"] = true
      end

      if (@wait_for_non_stale_results ||
          @wait_for_non_stale_results_as_of_now) &&
          !@wait_for_non_stale_results_timeout.nil?
        json["WaitForNonStaleResultsTimeout"] = @wait_for_non_stale_results_timeout.to_s

      end

      json
    end
  end

  class QueryOperationOptions
    attr_reader :allow_stale, :stale_timeout, :max_ops_per_sec, :retrieve_details

    def initialize(allow_stale = true, stale_timeout = nil, max_ops_per_sec = nil, retrieve_details = false)
      @allow_stale = allow_stale
      @stale_timeout = stale_timeout
      @max_ops_per_sec = max_ops_per_sec
      @retrieve_details = retrieve_details
    end
  end
end