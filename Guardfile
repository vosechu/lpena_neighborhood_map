notification :terminal_notifier if `uname`.strip == 'Darwin'

# Warn if not running with bundle exec
unless defined?(Bundler)
  puts "\n⚠️  WARNING: Guard should be run with 'bundle exec guard' for proper gem loading!"
  puts "   Notifications and other features may not work correctly.\n\n"
end

group :red_green_refactor, halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec', notification: true do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^app/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/(.+)\.erb$})    { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/controllers/application_controller\.rb$}) { 'spec/controllers' }
    watch(%r{^app/controllers/(.+)_controller\.rb$})        { |m| "spec/controllers/#{m[1]}_controller_spec.rb" }
    watch(%r{^app/jobs/(.+)\.rb$})                         { |m| "spec/jobs/#{m[1]}_spec.rb" }
    watch(%r{^app/models/(.+)\.rb$})                       { |m| "spec/models/#{m[1]}_spec.rb" }
    watch(%r{^app/services/(.+)\.rb$})                     { |m| "spec/services/#{m[1]}_spec.rb" }
    watch(%r{^lib/connections/(.+)\.rb$})                  { |m| "spec/connections/#{m[1]}_spec.rb" }
    watch('spec/spec_helper.rb')  { "spec" }
    watch('config/routes.rb')     { "spec/routing" }
    watch('app/controllers/application_controller.rb')  { "spec/controllers" }

    # Run all specs after a specific spec passes
    callback(:start_end) do |event, data|
      if event == :end && data[:status] == 0
        ::Guard::Notifier.notify('Running all specs...', title: 'Guard', image: :pending)
        system('bundle exec rspec')
      end
    end
  end

  guard :rubocop, cli: [ '--format', 'simple' ], notification: true, all_on_start: false do
    watch(%r{^app/(.+)\.rb$})
    watch(%r{^lib/(.+)\.rb$})
    watch(%r{^spec/(.+)\.rb$})
    watch(%r{^config/(.+)\.rb$})
    watch(%r{^Gemfile$})
    watch(%r{^Rakefile$})
    watch(%r{^Guardfile$})
  end
end

# Disable interactor for CI environments or when running in a non-interactive shell
interactor :off if ENV['CI'] || !$stdin.tty?
