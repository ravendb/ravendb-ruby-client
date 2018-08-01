module RavenDB
  class SaveChangesData
    attr_reader :deferred_commands
    attr_reader :session_commands
    attr_reader :entities
    attr_reader :options
    attr_reader :deferred_commands_map

    def initialize(session)
      @deferred_commands = session.deferred_commands.dup
      @deferred_commands_map = session.deferred_commands_map.dup
      @options = session._save_changes_options
      @entities = []
      @session_commands = []
    end
  end
end
