module RavenDB
  class GetStatisticsOperation < AdminOperation
    def initialize(debug_tag: false)
      @debug_tag = debug_tag
    end

    def get_command(conventions:, store: nil, http_cache: nil)
      GetStatisticsCommand.new(debug_tag: @debug_tag)
    end
  end
end
