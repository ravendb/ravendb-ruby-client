Gem::Specification.new do |spec|
  spec.name        = "ravendb"
  spec.version     = "4.0.0-rc1"
  spec.date        = "2017-11-01"
  spec.summary     = "RavenDB"
  spec.description = "RavenDB client for Ruby"
  spec.authors     = ["Hibernating Rhinos"]
  spec.email       = "support@ravendb.net"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test)/})
  spec.require_paths = ["lib"]

  spec.add_dependency("activesupport")
  spec.add_dependency("openssl")
  spec.add_development_dependency("rubocop", "~> 0.52.1")

  spec.homepage = "http://ravendb.net"
  spec.license  = "MIT"
end