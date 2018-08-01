module RavenDB
  class RavenCommand
    ETAG_HEADER = "ETag".freeze

    attr_accessor :result
    attr_accessor :status_code
    attr_reader :response_type
    attr_reader :failed_nodes

    def initialize(end_point = nil, method = Net::HTTP::Get::METHOD, params = {}, payload = nil, headers = {})
      @end_point = end_point || ""
      @method = method
      @params = params
      @payload = payload
      @headers = headers
      @failed_nodes = Set.new([])
      @_last_response = nil
      @mapper = JsonObjectMapper.new
      @response_type = :object
    end

    def can_cache?
      false
    end

    def server_response
      @_last_response
    end

    def was_failed?
      !@failed_nodes.empty?
    end

    def add_failed_node(node)
      assert_node(node)
      @failed_nodes.add(node)
    end

    def was_failed_with_node?(node)
      assert_node(node)
      @failed_nodes.include?(node)
    end

    def create_request(_server_node)
      raise NotImplementedError, "You should implement create_request method in #{self.class}"
    end

    def to_request_options
      end_point = @end_point

      unless @params.empty?
        encoded_params = URI.encode_www_form(@params)
        end_point = "#{end_point}?#{encoded_params}"
      end

      request_ctor = Object.const_get("Net::HTTP::#{@method.capitalize}")
      request = request_ctor.new(end_point)

      if !@payload.nil? && !@payload.empty?
        begin
          request.body = JSON.generate(@payload)
        rescue JSON::GeneratorError
          raise "Invalid payload specified. Can be JSON object only"
        end
        @headers["Content-Type"] = "application/json"
      end

      unless @headers.empty?
        @headers.each do |header, value|
          request.add_field(header, value)
        end
      end

      request
    end

    def set_response(response)
      @_last_response = response

      return unless @_last_response

      ExceptionsFactory.raise_from(response)
      response.json
    end

    def read_request?
      raise NotImplementedError, "You should implement read_request? method in #{self.class}"
    end

    def send_request(http_client, request)
      RavenDB.logger.debug(_color("#{self.class} #{request.method} #{request.path} body: #{request.body} headers: #{request.to_hash}", :cyan, :bold))
      response = http_client.request(request)
      error = response.code.to_i >= 400
      RavenDB.logger.warn(_color("#{self.class} response: #{response.code} #{response.message}", error ? :red : :green, :bold))
      if ENV["DEBUG"] || error
        RavenDB.logger.warn(_color("#{self.class} #{response.body}", error ? :red : :green))
      end
      response
    end

    def _color(text, *colors)
      if defined?(Rainbow)
        text = Rainbow(text)
        colors.each do |color|
          text = text.send(color)
        end
      end
      text
    end

    def on_response_failure(_response)
    end

    def process_response(cache, response, url, conventions:)
      entity = response

      if entity.nil?
        return :automatic
      end

      if response_type == :empty || response.is_a?(Net::HTTPNoContent)
        return :automatic
      end

      if response_type == :object
        content_length = entity.content_length
        if content_length == 0
          return :automatic
        end

        # we intentionally don't dispose the reader here, we'll be using it
        # in the command, any associated memory will be released on context reset
        json = JSON.parse(entity.body)
        unless cache.nil? # precaution
          cache_response(cache, url, response, json)
        end

        self.result = parse_response(json, from_cache: false, conventions: conventions)
        return :automatic
      else
        self.result = parse_response_raw(response)
      end

      :automatic
    end

    def set_response_raw(response)
      set_response(response)
      parse_response_raw(response)
    end

    def cache_response(cache, url, response, response_json)
      unless can_cache?
        return
      end

      change_vector = response[ETAG_HEADER]
      return if change_vector.nil?

      cache.set(url, change_vector, response_json)
    end

    protected

    def assert_node(node)
      raise ArgumentError, "Argument \"node\" should be an instance of ServerNode" unless node.is_a? ServerNode
    end

    def raise_invalid_response!
      raise ErrorResponseException, "Invalid server response"
    end

    def add_params(param_or_params, value)
      new_params = param_or_params

      unless new_params.is_a?(Hash)
        new_params = {}
        new_params[param_or_params] = value
      end

      @params = @params.merge(new_params)
    end

    def remove_params(param_or_params, *other_params)
      remove = param_or_params

      unless remove.is_a?(Array)
        remove = [remove]
      end

      unless other_params.empty?
        remove = remove.concat(other_params)
      end

      remove.each { |param| @params.delete(param) }
    end

    def parse_response(json, from_cache:, conventions:)
      json
    end

    def path_with_params(end_point, params)
      end_point += "?" + URI.encode_www_form(params) if params && !params.empty?
      end_point
    end
  end

  # to be removed
  class RavenCommandUnified < RavenCommand
    def set_response(response)
      response = super(response)

      raise_invalid_response! unless response.is_a?(Hash)

      parse_response(response, from_cache: nil)
    end
  end
end
