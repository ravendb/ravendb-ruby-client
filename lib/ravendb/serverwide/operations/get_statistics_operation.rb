module RavenDB
  class GetStatisticsOperation < AdminOperation
    def get_command(_conventions)
      GetStatisticsCommand.new
    end
  end
end
