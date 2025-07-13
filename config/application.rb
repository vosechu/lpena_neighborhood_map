require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LpenaNeighborhoodMap
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Set RSpec as the default test framework
    config.generators do |g|
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: false,
        request_specs: true
    end

    # Use Sidekiq for background jobs
    config.active_job.queue_adapter = :sidekiq

    # Configure semantic logging
    config.semantic_logger.application = 'lpena_neighborhood_map'
    config.semantic_logger.environment = Rails.env
    config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')

    # Enable verbose query logs with call stack in development
    if Rails.env.development?
      config.active_record.verbose_query_logs = true
      config.active_record.logger = SemanticLogger['ActiveRecord']
    end

    # Use JSON logging in production
    if Rails.env.production?
      config.rails_semantic_logger.add_file_appender = false
      config.semantic_logger.add_appender(io: $stdout, formatter: :json)
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
