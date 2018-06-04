module RavenDB
  class DatabaseDocument
    attr_reader :database_id, :settings

    def initialize(database_id, settings = {}, disabled = false, encrypted = false)
      @database_id = database_id
      @settings = settings
      @disabled = disabled
      @encrypted = encrypted
    end

    def to_json
      {
        "DatabaseName" => @database_id,
        "Disabled" => @disabled,
        "Encrypted" => @encrypted,
        "Settings" => @settings
      }
    end
  end
end
