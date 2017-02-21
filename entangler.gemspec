# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.47'
  spec.add_dependency 'listen', '~> 3.1'
  spec.add_dependency 'to_regexp', '~> 0.2'
end
