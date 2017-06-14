# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "sidekiq-trackable_batch"
  spec.version       = "0.1.0"
  spec.authors       = ["darrhiggs"]
  spec.email         = ["darrhiggs+git@gmail.com"]

  spec.summary       = %q{Detailed `Sidekiq::Batch` progress}
  spec.description   = %q{Access detailed & up-to-date progress information for `Sidekiq::Batch`}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "appraisal", "~> 2.1"
end
