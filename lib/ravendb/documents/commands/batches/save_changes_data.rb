module RavenDB
  class SaveChangesData
    attr_reader :deferred_commands_count

    def commands_count
      @commands.size
    end

    def initialize(commands = nil, deferred_command_count = 0, documents = nil)
      @commands = commands || []
      @documents = documents || []
      @deferred_commands_count = deferred_command_count
    end

    def add_command(command)
      @commands.push(command)
    end

    def add_document(document)
      @documents.push(document)
    end

    def get_document(index)
      @documents.at(index)
    end

    def create_batch_command
      BatchCommand.new(@commands)
    end
  end
end
