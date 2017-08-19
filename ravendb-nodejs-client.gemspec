Gem::Specification.new do |spec|
  spec.name        = 'ravendb'
  spec.version     = '4.0.0-beta'
  spec.date        = '2017-08-14'
  spec.summary     = "RavenDB"
  spec.description = "RavenDB client for Ruby"
  spec.authors     = ["Hibernating Rhinos"]
  spec.email       = 'support@ravendb.net'
  
  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.filespec.grep(%r{^(test)/})
  spec.require_paths = ['lib']

  spec.homepage = 'http://ravendb.net'
  spec.license  = 'MIT'
end