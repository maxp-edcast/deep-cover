# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in deep_cover.gemspec
gemspec

eval_gemfile File.expand_path('Gemfile.local', __dir__) if File.exist?('Gemfile.local')

gem 'deep-cover-core', path: 'core_gem'

gem 'ruby-prof', platforms: :mri
