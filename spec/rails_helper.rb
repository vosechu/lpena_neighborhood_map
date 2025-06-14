# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
require 'webmock/rspec'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
require 'capybara/rspec'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Capybara.register_driver :chrome_with_console do |app|
  options = Selenium::WebDriver::Options.chrome
  options.add_option('goog:loggingPrefs', { browser: 'ALL' })
  # Run in headless mode so no browser window pops during tests (Chrome 109+ flag)
  options.add_argument('--headless=new')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :chrome_with_console

# Helper function for taking screenshots on timeout failures
def screenshot_on_timeout(screenshot_name, description, &block)
  block.call
rescue Timeout::Error, RSpec::Expectations::ExpectationNotMetError => e
  # Create screenshots directory if it doesn't exist
  FileUtils.mkdir_p('tmp/screenshots')
  # Take screenshot on timeout/expectation failure
  page.save_screenshot("tmp/screenshots/#{screenshot_name}.png")
  raise e, "#{description}: #{e.message} - screenshot saved to tmp/screenshots/#{screenshot_name}.png"
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a database transaction, remove the following line or assign
  # false instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec-info.github.io/rspec-rails/file.method-summary.html

  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Configure WebMock
  config.before(:each) do
    # Deny all web requests by default
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Configure FactoryBot
  config.include FactoryBot::Syntax::Methods

  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Warden::Test::Helpers

  config.before(:suite) do
    log_path = Rails.root.join('log/test.log')
    File.truncate(log_path, 0) if File.exist?(log_path)
  end

  # Configure inline job processing for tests to avoid Redis dependency
  config.before(:each) do
    ActiveJob::Base.queue_adapter = :test
    # Clear any enqueued jobs before each test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear
  end
end
