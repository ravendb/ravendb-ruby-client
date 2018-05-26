module RavenDB
  class CreateSampleDataOperation < AdminOperation
    def get_command(conventions:, store: nil, http_cache: nil)
      CreateSampleDataCommand.new
    end
  end
end
