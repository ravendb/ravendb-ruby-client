require 'thread'
require 'documents/conventions'
require 'utilities/type_utilities'
require 'database/commands'
require 'database/exceptions'

module RavenDB
  class HiloRangeValue
    attr_reader :min_id, :max_id, :current

    def initialize(min_id = 1, max_id = 0)
      @min_id = min_id
      @max_id = max_id
      @current = min_id
    end

    def increment
      @current = @current + 1
    end

    def needs_new_range?
      @current >= @max_id
    end
  end

  class AbstractHiloIdGenerator
    def initialize(store, db_name = nil, tag = nil)
      @tag = tag
      @store = store
      @db_name = db_name
      @conventions = store.conventions
      @generators = {}
    end

    def return_unused_range
      @generators.each_value do |generator|
        begin
          generator.return_unused_range
        rescue
          nil
        end
      end
    end
  end

  class HiloIdGenerator < AbstractHiloIdGenerator
    attr_reader :range

    def initialize(store, db_name, tag)
      super(store, db_name, tag)
      @prefix = ''
      @server_tag = nil
      @last_batch_size = 0
      @range = HiloRangeValue.new
      @generate_id_lock = Mutex.new
      @last_range_at = TypeUtilities::zero_date
      @identity_parts_separator = DocumentConventions::IdentityPartsSeparator
    end

    def generate_document_id
      new_range = try_request_next_range
      assemble_document_id(new_range.current)
    end

    def return_unused_range
      return_command = HiloReturnCommand.new(@tag, @range.current, @range.max_id)
      @store.get_request_executor(@db_name).execute(return_command)
    end

    protected
    def try_request_next_range
      @generate_id_lock.synchronize do
        if !@range.needs_new_range?
          @range.increment
        elsif
          begin
            @range = get_next_range
          rescue ConcurrencyException
            @range = try_request_next_range
          end
        end

        @range
      end
    end

    def get_next_range
      next_command = HiloNextCommand.new(@tag, @last_batch_size, @last_range_at, @identity_parts_separator, @range.max_id)
      response = @store.get_request_executor(@db_name).execute(next_command)

      @prefix = response['prefix']
      @last_batch_size = response['last_size']
      @server_tag = response['server_tag'] || nil
      @last_range_at = TypeUtilities::parse_date(response['last_range_at'])

      HiloRangeValue.new(response['low'], response['high'])
    end

    def assemble_document_id(current_range_value)
      prefix = @prefix || ''
      document_id = "#{prefix}#{current_range_value}"

      if !@server_tag.nil? && !(@server_tag == '')
        document_id = "#{document_id}-#{@server_tag}"
      end

      document_id
    end
  end

  class HiloMultiTypeIdGenerator < AbstractHiloIdGenerator
    def initialize(store, db_name)
      super(store, db_name)
      @get_generator_lock = Mutex.new
    end

    def generate_document_id(tag = nil)
      if @conventions.empty_collection == tag
        tag = nil
      end

      get_generator_for_tag(tag).generate_document_id()
    end

    protected
    def get_generator_for_tag(tag)
      @get_generator_lock.synchronize do
        if !@generators.key?(tag)
          @generators[tag] = HiloIdGenerator.new(@store, @db_name, tag)
        end

        @generators[tag]
      end
    end
  end

  class HiloMultiDatabaseIdGenerator < AbstractHiloIdGenerator
    def initialize(store)
      super(store)
      @get_generator_lock = Mutex.new
    end

    def generate_document_id(tag = nil, db_name = nil)
      get_generator_for_database(db_name || @store.database).generate_document_id(tag)
    end

    protected
    def get_generator_for_database(db_name)
      @get_generator_lock.synchronize do
        if !@generators.key?(db_name)
          @generators[db_name] = HiloMultiTypeIdGenerator.new(@store, db_name)
        end

        @generators[db_name]
      end
    end
  end
end