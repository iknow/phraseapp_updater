#! /usr/bin/env nix-shell
#! nix-shell -i ruby -p ruby -p bundler -p bundix
# frozen_string_literal: true

# Bundix doesn't support `gemspec` directive in Gemfiles, as it doesn't copy the
# gemspec (and its dependencies) into the store.
# This workaround is from https://github.com/manveru/bundix/issues/10#issuecomment-405879379

require 'shellwords'
require 'uri'

def sh(*args)
  warn args.shelljoin
  system(*args) || raise
end

sh 'bundle', 'lock'

require 'fileutils'
require 'bundler'

lockfile = Bundler::LockfileParser.new(File.read('Gemfile.lock'))
gems = lockfile.specs.select { |spec| spec.source.is_a?(Bundler::Source::Rubygems) }
sources = [URI('https://rubygems.org/')] | gems.map(&:source).flat_map(&:remotes)

FileUtils.mkdir_p 'nix/gem'
Dir.chdir 'nix/gem' do
  ['Gemfile', 'Gemfile.lock', 'gemset.nix'].each do |f|
    File.delete(f) if File.exist?(f)
  end

  File.open('Gemfile', 'w') do |gemfile|
    sources.each { |source| gemfile.puts "source #{source.to_s.inspect}" }
    gemfile.puts

    gems.each do |gem|
      gemfile.puts "gem #{gem.name.inspect}, #{gem.version.to_s.inspect}"
    end
  end

  sh 'bundix', '-l'
end
