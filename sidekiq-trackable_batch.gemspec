# coding: utf-8
# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-trackable_batch'
  spec.version       = '0.1.0'
  spec.authors       = ['darrhiggs']
  spec.email         = ['darrhiggs+os@gmail.com']

  spec.summary       = 'Detailed `Sidekiq::Batch` progress'
  spec.description   = 'Access detailed & up-to-date progress information'\
                       ' for `Sidekiq::Batch`'
  spec.homepage      = 'https://github.com/darrhiggs/sidekiq-trackable_batch'
  spec.license       = 'MIT'

  spec.files = Dir["CHANGELOG.md", "LICENSE.txt", "README.md", "lib/**/*"]

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'sidekiq'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'appraisal', '~> 2.1'
  spec.add_development_dependency 'redcarpet' # github flavored markdown with YARD
end
