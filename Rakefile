require "optparse"
require "rake/testtask"
require "ci/reporter/rake/rspec"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

Rake::TestTask.new do |task|
  task.libs << "test"
  task.verbose = true
  task.test_files = FileList["test/raven_commands_tests/*.rb", "test/session_tests/*.rb"]
end

desc "Run unit tests"
task default: :spec
task test_ci: ["ci:setup:rspec", :test]

task :reset do
  system("docker rm -f ravendb; docker run -d --name ravendb -p 8080:8080 ravendb/ravendb")
end
