require "date"
require_relative "./lib/version.rb"

Gem::Specification.new do |spec|
  spec.name        = "ravendb"
  spec.version     = RavenDB::VERSION
  spec.date        = Date.today.to_s
  spec.summary     = "RavenDB"
  spec.description = "RavenDB client for Ruby"
  spec.authors     = ["Hibernating Rhinos"]
  spec.email       = "support@ravendb.net"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|example)/}) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("activesupport")
  spec.add_runtime_dependency("concurrent-ruby")
  spec.add_runtime_dependency("openssl")

  spec.add_development_dependency("rainbow", "~> 3.0.0")
  spec.add_development_dependency("rake", "~> 12.3.0")
  spec.add_development_dependency("rspec", "~> 3.7.0")
  spec.add_development_dependency("rubocop", "~> 0.53.0")
  spec.add_development_dependency("rubocop-rspec", "~> 1.24.0")
  spec.add_development_dependency("simplecov", "~> 0.15.1")

  spec.homepage = "http://ravendb.net"
  spec.license  = "MIT"
end
