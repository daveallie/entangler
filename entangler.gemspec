# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'entangler/version'

Gem::Specification.new do |spec|
  spec.name          = "entangler"
  spec.version       = Entangler::VERSION
  spec.authors       = ["Dave Allie"]
  spec.email         = ["dave@daveallie.com"]

  spec.summary       = %q{Two way file syncer using platform native notify and rdiff syncing.}
  spec.description   = %q{Two way file syncer using platform native notify and rdiff syncing.}
  spec.homepage      = "https://github.com/daveallie/entangler"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_dependency "lib_ruby_diff", "~> 0.1"
end
