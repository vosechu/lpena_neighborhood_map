require 'mailgun-ruby'

# Mailgun HTTP API delivery method for Action Mailer
class MailgunDeliveryMethod
  attr_accessor :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    # Initialize Mailgun client
    mg_client = Mailgun::Client.new(@settings[:api_key], @settings[:api_host] || 'api.mailgun.net')

    # Prepare message data
    message_data = {
      from: mail.from.first,
      to: mail.to,
      subject: mail.subject,
      html: mail.html_part&.body&.to_s || mail.body.to_s
    }

    # Add text part if available
    if mail.text_part
      message_data[:text] = mail.text_part.body.to_s
    end

    # Add CC if present
    message_data[:cc] = mail.cc if mail.cc&.any?

    # Add BCC if present  
    message_data[:bcc] = mail.bcc if mail.bcc&.any?

    # Send the message
    mg_client.send_message(@settings[:domain], message_data)
  end
end

# Register the delivery method
ActionMailer::Base.add_delivery_method :mailgun, MailgunDeliveryMethod