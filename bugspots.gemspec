# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'bugspots/version'

Gem::Specification.new do |s|
  s.name        = 'bugspots'
  s.version     = Bugspots::VERSION
  s.authors     = ['Ilya Grigorik']
  s.email       = ['ilya@igvita.com']
  s.homepage    = 'https://github.com/igrigorik/bugspots'
  s.summary     = 'Implementation of simple bug prediction hotspot heuristic'
  s.description = s.summary

  s.rubyforge_project = 'bugspots'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 4.0.1', '< 5.0'

  s.add_dependency 'rainbow'
  s.add_dependency 'rugged', '>= 1.7.2'

  s.add_development_dependency 'bundler-audit'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rubocop', '~> 1.76'
end
