module RavenDB
  class GetStatisticsOperation < AdminOperation
    def get_command(conventions:, store: nil, http_cache: nil)
      GetStatisticsCommand.new
    end
  end
end
