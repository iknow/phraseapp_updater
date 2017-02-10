# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'phraseapp_updater/version'

Gem::Specification.new do |spec|
  spec.name          = "phraseapp_updater"
  spec.version       = PhraseappUpdater::VERSION
  spec.authors       = ["Kevin Griffin"]
  spec.email         = ["kev@bibo.com.ph"]

  spec.summary       = %q{A three-way differ for PhraseApp projects.}
  spec.description   = %q{A tool for merging data on PhraseApp with local changes (usually two git revisions)}
  spec.homepage      = "app.engoo.com"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = ["phraseapp_updater"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 0.19"
  spec.add_dependency "phraseapp-ruby", "~> 1.3"
  spec.add_dependency "hashdiff", "~> 0.3"
  spec.add_dependency "multi_json", "~> 1.12"
  spec.add_dependency "oj", "~> 2.18"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.10"
end
