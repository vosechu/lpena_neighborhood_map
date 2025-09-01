source 'https://rubygems.org'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.0.2'

# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'

# Use postgresql as the database for Active Record
gem 'pg'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma'

# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem 'tailwindcss-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# HTTP client for making API requests
gem 'httparty'

# Background job processing
gem 'sidekiq'
gem 'sidekiq-scheduler'

# Email delivery via Mailgun HTTP API
gem 'mailgun-ruby'

# Authentication and authorization
gem 'devise'
gem 'cancancan'

# Admin interface - Rails 8 compatible
gem 'avo'
gem 'ransack' # For search functionality in Avo

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem 'solid_cache'
gem 'solid_cable'

# Importmaps and Stimulus
gem 'importmap-rails'
gem 'stimulus-rails'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Structured logging for Rails applications
gem 'amazing_print' # colorized output of semantic data (Hash output)
gem 'rails_semantic_logger'

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

# Application performance monitoring
gem 'newrelic_rpm'

# Email sending with DKIM/DMARC so it doesn't get marked as spam
gem 'mailgun-ruby'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[ mri windows ], require: 'debug/prelude'

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem 'rubocop-rails-omakase', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Guard for automated testing
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'terminal-notifier-guard'
  gem 'ruby_gntp'  # For cross-platform notifications

  # Email testing for dev mode
  gem 'letter_opener'
end

group :test do
  # Testing framework
  gem 'rspec-rails'
  gem 'rspec-mocks'

  # Test data generation
  gem 'factory_bot_rails'

  # Feature testing
  gem 'capybara'
  gem 'selenium-webdriver'

  # Time manipulation for testing
  gem 'timecop'

  # HTTP request mocking
  gem 'webmock'

  # SQLite for faster unit/request tests
  gem 'sqlite3'
end
