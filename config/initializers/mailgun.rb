# Configure Mailgun SMTP settings for production
if Rails.env.production?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: 'smtp.mailgun.org',
      port: 587,
      domain: 'lakepasadenaestates.com',
      user_name: 'no-reply@lakepasadenaestates.com',
      password: ENV['MAILGUN_SMTP_PASSWORD'],
      authentication: :plain,
      enable_starttls_auto: true
    }

    # Set default URL options for the Devise mailer
    config.action_mailer.default_url_options = {
      host: ENV.fetch('HOST', 'neighborhood.lakepasadenaestates.com'),
      protocol: ENV.fetch('RAILS_PROTOCOL', 'https')
    }
  end
end
