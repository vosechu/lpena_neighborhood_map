class AdminNotificationMailer < ApplicationMailer
  default from: 'noreply@neighborhoodmap.org'

  def data_conflict_notification(conflicts, summary, job_duration)
    @conflicts = conflicts
    @summary = summary
    @job_duration = job_duration
    @timestamp = Time.current

    mail(
      to: 'vosechu@gmail.com',
      subject: "Data Conflicts Detected - #{conflicts.length} conflicts found"
    )
  end

  def job_failure_notification(error_message, job_duration)
    @error_message = error_message
    @job_duration = job_duration
    @timestamp = Time.current

    mail(
      to: 'vosechu@gmail.com',
      subject: 'Property Data Import Job Failed'
    )
  end
end