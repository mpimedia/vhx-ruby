lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vhx/version'

Gem::Specification.new do |spec|
  spec.name           = 'vhx-ruby'
  spec.version        = Vhx::VERSION
  spec.authors        = ['Vimeo OTT Developers']
  spec.description    = 'A Ruby wrapper for the VHX developer API.'
  spec.summary        = 'A Ruby wrapper for the VHX developer API.'
  spec.email          = ['dev@vhx.tv']
  spec.homepage       = 'http://dev.vhx.tv/docs/api/'
  spec.license        = 'MIT'

  spec.files          = `git ls-files`.split("\n")
  spec.executables    = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  spec.test_files     = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths  = ['lib']

  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'ostruct'

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock'
end
