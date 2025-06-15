class ApplicationMailer < ActionMailer::Base
  include ActiveJob::QueueName  # Required for queue_as in Rails 8.0
  default from: 'no-reply@lakepasadenaestates.com'
  layout 'mailer'
end
