namespace :admin do
  desc 'Create the first admin user'
  task create_first: :environment do
    puts 'Creating first admin user...'

    email = ENV['ADMIN_EMAIL']
    name = ENV['ADMIN_NAME'] || 'Admin'

    if email.blank?
      puts 'Please provide ADMIN_EMAIL environment variable'
      puts "Usage: ADMIN_EMAIL=admin@example.com ADMIN_NAME='Admin User' rails admin:create_first"
      exit 1
    end

    # Check if any admin already exists
    if User.where(role: 'admin').exists?
      puts 'Admin user already exists. Skipping creation.'
      exit 0
    end

    # Check if user with this email already exists
    if User.exists?(email: email)
      puts "User with email #{email} already exists. Skipping creation."
      exit 1
    end

    begin
      user = UserCreationService.create_user(
        email: email,
        name: name,
        role: 'admin',
        send_invitation: false
      )

      # Generate initial login token
      login_token = UserCreationService.generate_initial_login_token(user)

      puts '✅ Admin user created successfully!'
      puts "Email: #{user.email}"
      puts "Name: #{user.name}"
      puts "Role: #{user.role}"
      puts ''
      puts '🔑 Initial login URL:'
      puts "#{Rails.application.routes.url_helpers.edit_user_password_url(reset_password_token: login_token, host: ENV.fetch('APP_HOST', 'localhost:3000'))}"
      puts ''
      puts 'The admin can use this URL to set their password and access the system.'
      puts "This token expires in #{Devise.reset_password_within / 1.hour} hours."

    rescue ActiveRecord::RecordInvalid => e
      puts "❌ Failed to create admin user: #{e.message}"
      exit 1
    end
  end

  desc 'Create additional admin user'
  task create: :environment do
    puts 'Creating additional admin user...'

    email = ENV['ADMIN_EMAIL']
    name = ENV['ADMIN_NAME'] || 'Admin'

    if email.blank?
      puts 'Please provide ADMIN_EMAIL environment variable'
      puts "Usage: ADMIN_EMAIL=admin@example.com ADMIN_NAME='Admin User' rails admin:create"
      exit 1
    end

    # Check if user with this email already exists
    if User.exists?(email: email)
      puts "User with email #{email} already exists. Skipping creation."
      exit 1
    end

    begin
      user = UserCreationService.create_user(
        email: email,
        name: name,
        role: 'admin',
        send_invitation: false
      )

      # Generate initial login token
      login_token = UserCreationService.generate_initial_login_token(user)

      puts '✅ Admin user created successfully!'
      puts "Email: #{user.email}"
      puts "Name: #{user.name}"
      puts "Role: #{user.role}"
      puts ''
      puts '🔑 Initial login URL:'
      puts "#{Rails.application.routes.url_helpers.edit_user_password_url(reset_password_token: login_token, host: ENV.fetch('APP_HOST', 'localhost:3000'))}"
      puts ''
      puts 'The admin can use this URL to set their password and access the system.'
      puts "This token expires in #{Devise.reset_password_within / 1.hour} hours."

    rescue ActiveRecord::RecordInvalid => e
      puts "❌ Failed to create admin user: #{e.message}"
      exit 1
    end
  end

  desc 'List all admin users'
  task list: :environment do
    admins = User.where(role: 'admin')

    if admins.empty?
      puts 'No admin users found.'
    else
      puts 'Admin users:'
      admins.each do |admin|
        puts "- #{admin.name} (#{admin.email}) - Created: #{admin.created_at.strftime('%Y-%m-%d %H:%M')}"
      end
    end
  end
end
