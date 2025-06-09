class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'

  # Email safety check for non-production environments
  after_action :ensure_safe_email_delivery

  private

  def ensure_safe_email_delivery
    unless Rails.env.production?
      Rails.logger.info "Email Safety: ApplicationMailer safety check - environment: #{Rails.env}"

      # Double-check that we're not accidentally sending to real emails in test
      if Rails.env.test? && mail.to&.any? { |email| !email.include?('example.com') }
        Rails.logger.error "Email Safety: DANGER! Test environment trying to send to real email: #{mail.to.join(', ')}"
        raise "EMAIL SAFETY VIOLATION: Test environment attempted to send email to real address: #{mail.to.join(', ')}"
      end
    end
  end
end
