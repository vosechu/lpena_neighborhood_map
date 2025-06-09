# Email Safety Configuration
# Prevents test/development emails from reaching real users

Rails.logger.info "Email Safety: Loading email safety initializer in #{Rails.env} environment"

# Only allow real email delivery in production
unless Rails.env.production?
  Rails.logger.info "Email Safety: Non-production environment detected (#{Rails.env}). Email safety measures activated."
end

# Email interceptor for development/staging environments
class EmailSafetyInterceptor
  def self.delivering_email(message)
    # Log all outgoing emails for debugging
    Rails.logger.info "Email Safety: Attempting to send email to #{message.to.join(', ')} with subject '#{message.subject}'"

    case Rails.env
    when 'test'
      # Test environment - emails should never actually be sent
      Rails.logger.info 'Email Safety: TEST environment - email delivery blocked'
      message.perform_deliveries = false

    when 'development'
      # Development environment - redirect all emails to safe addresses or files
      Rails.logger.info 'Email Safety: DEVELOPMENT environment - email redirected to file system'
      # Emails are already configured to go to files in development.rb

    when 'staging'
      # Staging environment - redirect to safe test addresses
      Rails.logger.warn 'Email Safety: STAGING environment - redirecting emails to safe test addresses'
      redirect_to_safe_addresses(message)

    when 'production'
      # Production environment - allow normal delivery but log it
      Rails.logger.info 'Email Safety: PRODUCTION environment - allowing normal email delivery'

    else
      # Unknown environment - block all emails as safety measure
      Rails.logger.error "Email Safety: UNKNOWN environment (#{Rails.env}) - blocking all email delivery as safety measure"
      message.perform_deliveries = false
    end
  end

  private

  def self.redirect_to_safe_addresses(message)
    original_to = message.to.dup
    original_cc = message.cc&.dup
    original_bcc = message.bcc&.dup

    # Define safe test email addresses
    safe_addresses = [
      'test+staging@example.com',
      'dev+staging@example.com'
    ]

    # Redirect all recipients to safe addresses
    message.to = safe_addresses
    message.cc = []
    message.bcc = []

    # Add original recipients to email body for debugging
    original_recipients = []
    original_recipients.concat(original_to.map { |email| "TO: #{email}" }) if original_to&.any?
    original_recipients.concat(original_cc.map { |email| "CC: #{email}" }) if original_cc&.any?
    original_recipients.concat(original_bcc.map { |email| "BCC: #{email}" }) if original_bcc&.any?

    if original_recipients.any?
      message.body = "STAGING EMAIL REDIRECT\n" \
                     "Original recipients: #{original_recipients.join(', ')}\n" \
                     "Original subject: #{message.subject}\n\n" \
                     "---\n\n" \
                     "#{message.body}"
    end

    Rails.logger.info "Email Safety: Redirected from #{original_to.join(', ')} to #{safe_addresses.join(', ')}"
  end
end

# Register the interceptor for non-production environments
unless Rails.env.production?
  Rails.logger.info "Email Safety: Registering EmailSafetyInterceptor for #{Rails.env} environment"
  ActionMailer::Base.register_interceptor(EmailSafetyInterceptor)
  Rails.logger.info "Email Safety: Interceptor registered. Current interceptors: #{ActionMailer::Base.instance_variable_get(:@mail_interceptors) || []}"
end
