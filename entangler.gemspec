# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'entangler/version'

Gem::Specification.new do |spec|
  spec.name          = 'entangler'
  spec.version       = Entangler::VERSION
  spec.authors       = ['Dave Allie']
  spec.email         = ['dave@daveallie.com']

  spec.summary       = 'Two way file syncer using platform native notify.'
  spec.description   = 'Two way file syncer using platform native notify.'
  spec.homepage      = 'https://github.com/daveallie/entangler'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*'] + Dir['exe/**/*'] + %w[CODE_OF_CONDUCT.md LICENSE.txt README.md
                                                              Gemfile entangler.gemspec]
  spec.bindir        = 'exe'
  spec.executables   = ['entangler']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.5'

  spec.add_development_dependency 'bundler', '>= 2.1'
  spec.add_development_dependency 'rake', '>= 13.0.1'
  spec.add_development_dependency 'rspec', '>= 3.9'
  spec.add_development_dependency 'rubocop', '~> 1.6'
  spec.add_development_dependency 'rubocop-rake', '~> 0.5.1'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.0'
  spec.add_dependency 'listen', '~> 3.7'
  spec.add_dependency 'to_regexp', '~> 0.2.1'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
