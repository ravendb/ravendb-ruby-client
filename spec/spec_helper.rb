require "simplecov"
SimpleCov.start

require "ravendb"
require "date"
require "securerandom"

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].sort.each { |f| require f }

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus

  config.example_status_persistence_file_path = "spec/examples.txt"

  config.disable_monkey_patching!

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.order = :random

  config.around do |example|
    RavenTest.setup(self)
    example.run
    RavenTest.teardown(self)
  end

  config.around :each, database: true do |example|
    RavenDatabaseTest.setup(self)
    example.run
    RavenDatabaseTest.teardown(self)
  end

  config.around :each, database_indexes: true do |example|
    RavenDatabaseIndexesTest.setup(self)
    example.run
    RavenDatabaseIndexesTest.teardown(self)
  end

  config.include RavenTestHelpers
  config.include RavenDatabaseTestHelpers, database: true
end
