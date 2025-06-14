require 'sidekiq'
require 'sidekiq-scheduler'
require 'newrelic_rpm'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Load the schedule
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(Rails.root.join('config/sidekiq_schedule.yml')) || {}
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
