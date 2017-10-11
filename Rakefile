require 'optparse'
require 'rake/testtask'

Rake::TestTask.new do |task|
  task.libs << "test"
  task.verbose = true
  task.test_files = FileList['test/raven_commands_tests/*.rb'] #, 'test/session_tests/*.rb'
end

desc "Run unit tests"
task :default => :test