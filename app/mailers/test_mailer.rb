class TestMailer < ApplicationMailer
  def test_email(to: 'test@example.com')
    mail(
      to: to,
      subject: 'Test Email from Lake Pasadena Estates',
      body: 'This is a test email to verify Mailgun configuration.'
    )
  end
end
