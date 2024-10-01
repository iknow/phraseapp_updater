# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'phraseapp_updater/version'

Gem::Specification.new do |spec|
  spec.name          = "phraseapp_updater"
  spec.version       = PhraseAppUpdater::VERSION
  spec.authors       = ["iKnow Team"]
  spec.email         = ["systems@iknow.jp"]

  spec.summary       = %q{A three-way differ for PhraseApp projects.}
  spec.description   = %q{A tool for merging data on PhraseApp with local changes (usually two git revisions)}
  spec.homepage      = "https://github.com/iknow/phraseapp_updater"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "bin/**/*", "LICENSE.txt", "README.md"]
  spec.bindir        = "bin"
  spec.executables   = ["phraseapp_updater"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.3.0"
  spec.add_dependency "phrase", "~> 2.20.0"
  spec.add_dependency "hashdiff", "~> 1.0.1"
  spec.add_dependency "oj", "~> 3.16"
  spec.add_dependency "deep_merge", "~> 1.2"
  spec.add_dependency "parallel", "~> 1.23"
  spec.add_dependency "concurrent-ruby", "~> 1.0.2"

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rake", "~> 13.1"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "pry", "~> 0.14"
end
