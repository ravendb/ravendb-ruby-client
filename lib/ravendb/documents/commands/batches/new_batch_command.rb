module RavenDB
  class NewBatchCommand < RavenCommand
    attr_reader :commands
    attr_reader :options
    attr_reader :conventions

    def initialize(conventions, commands, options = nil)
      super()
      @commands = commands
      @options = options
      @conventions = conventions
      raise ArgumentError, "conventions cannot be null" if conventions.nil?
      raise ArgumentError, "commands cannot be null" if commands.nil?
      commands.each do |command|
        next unless command.is_a?(PutAttachmentCommandData)
        # TODO
        put_attachment_command_data = command
        @_attachment_streams = LinkedHashSet.new if @_attachment_streams.nil?
        stream = put_attachment_command_data.stream
        unless @_attachment_streams.add(stream)
          put_attachment_command_helper.throw_stream_already
        end
      end
    end

    def create_request(server_node)
      node = server_node
      end_point = "/databases/#{node.database}/bulk_docs#{append_options}"
      request = Net::HTTP::Post.new(end_point, "Content-Type" => "application/json")

      request.body = payload.to_json

      if !@_attachment_streams.nil? && !@_attachment_streams.empty?
        # TODO
        entity_builder = multipart_entity_builder.create
        entity = request.entity
        begin
          baos = ByteArrayOutputStream.new
          entity.write_to(baos)
          entity_builder.add_binary_body("main", ByteArrayInputStream.new(baos.to_byte_array))
        rescue IOException => e
          raise RavenException.new("Unable to serialize BatchCommand", e)
        end
        name_counter = 1
        @_attachment_streams.each do |stream|
          input_stream_body = InputStreamBody.new(stream, nil)
          part = form_body_part_builder.create(("attachment" + name_counter += 1), input_stream_body).add_field("Command-Type", "AttachmentStream").build
          entity_builder.add_part(part)
        end
        request.entity = entity_builder.build
      end

      request
    end

    def payload
      {
        "Commands" => @commands.map { |command| command.serialize(conventions) }
      }
    end

    def set_response(response, _from_cache)
      if response.nil?
        raise IllegalStateException, "Got null response from the server after doing a batch, something is very wrong. Probably a garbled response."
      end
      @result = @mapper.read_value(response, JsonArrayResult)
    end

    def append_options
      options = {}
      return if @options.nil?
      if @options.wait_for_replicas?
        options["waitForReplicasTimeout"] = time_utils.duration_to_time_span(@options.wait_for_replicas_timeout)
        if @options.throw_on_timeout_in_wait_for_replicas?
          options["throwOnTimeoutInWaitForReplicas"] = true
        end
        options["numberOfReplicasToWaitFor"] = (@options.majority? ? "majority" : @options.number_of_replicas_to_wait_for)
      end
      if @options.wait_for_indexes?
        options["waitForIndexesTimeout"] = time_utils.duration_to_time_span(@options.wait_for_indexes_timeout)
        options["waitForIndexThrow"] = @options.throw_on_timeout_in_wait_for_indexes?
        @options.wait_for_specific_indexes&.each do |specific_index|
          options["waitForSpecificIndex"] = specific_index
        end
      end
      "?" + URI.encode_www_form(options)
    end

    def read_request?
      false
    end
  end
end
