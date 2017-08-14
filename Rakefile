require 'rake/testtask'

Rake::TestTask.new do |task|
  task.libs << 'test/raven_commands_tests'
  # task.libs << 'test/session_tests'
end

desc "Run unit tests"
task :default => :test