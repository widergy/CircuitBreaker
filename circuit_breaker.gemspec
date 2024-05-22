# frozen_string_literal: true

require_relative 'lib/circuit_breaker/version'

Gem::Specification.new do |spec|
  spec.name = 'circuit_breaker'
  spec.version = CircuitBreaker::VERSION
  spec.authors = ['Widergy']
  spec.email = ['PENDING']

  spec.summary = 'Ruby Circuit Breaker implementation'
  spec.description = 'This gem allows to build a Circuit Breaker patron'
  spec.homepage = 'https://github.com/widergy/CircuitBreaker'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.files = Dir['{app,config,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  spec.test_files = Dir['spec/**/*']

  # Rails
  spec.add_dependency 'rails', '> 5'

  # Awesome Print is a Ruby library that pretty prints Ruby objects in full color exposing their
  # internal structure with proper indentation
  spec.add_development_dependency 'awesome_print'

  spec.add_development_dependency 'rollbar'

  # Better Errors replaces the standard Rails error page with a much better and more useful
  # error page.
  spec.add_development_dependency 'better_errors'

  # Debugger
  spec.add_development_dependency 'byebug'

  # Factory
  spec.add_development_dependency 'faker'

  # Helper
  spec.add_development_dependency 'rails_best_practices'

  # Use for sending request to 3rd party APIs
  spec.add_development_dependency 'httparty'

  # RSpec testing framework for Ruby on Rails as a drop-in alternative to its default testing
  # framework, Minitest.
  spec.add_development_dependency 'rspec-rails'

  # Code style
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rails'
  spec.add_development_dependency 'rubocop-rspec'

  # Helper
  spec.add_development_dependency 'rubycritic'

  # Rspec helpers
  spec.add_development_dependency 'dotenv'
  spec.add_development_dependency 'shoulda-matchers'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'test-prof'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'webmock'
end
