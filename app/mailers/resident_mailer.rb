class ResidentMailer < ApplicationMailer
  default from: 'no-reply@lakepasadenaestates.com'
  queue_as :critical

  # Class method to handle conditional email sending
  def self.deliver_data_change_notification(resident, changes)
    return if resident.email_notifications_opted_out?

    data_change_notification(resident, changes).deliver_later
  end

  def welcome_new_user(resident, user)
    @resident = resident
    @user = user
    @login_token = UserCreationService.generate_initial_login_token(@user)
    @login_url = edit_user_password_url(reset_password_token: @login_token)
    @unsubscribe_url = one_click_unsubscribe_url(token: generate_opt_out_token(@resident))

    mail(
      to: @user.email,
      subject: 'Welcome to the Neighborhood Directory - Set up your account',
      'List-Unsubscribe' => "<#{@unsubscribe_url}>",
      'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click'
    )
  end

  def data_change_notification(resident, changes)
    @resident = resident
    @changes = changes
    @opt_out_url = opt_out_url(token: generate_opt_out_token(@resident))
    @unsubscribe_url = one_click_unsubscribe_url(token: generate_opt_out_token(@resident))

    mail(
      to: @resident.email,
      subject: 'Your neighborhood information has been updated',
      'List-Unsubscribe' => "<#{@unsubscribe_url}>",
      'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click'
    )
  end

  private

  def generate_opt_out_token(resident)
    # Generate a secure token for opt-out functionality
    Rails.application.message_verifier(:opt_out).generate({
      resident_id: resident.id,
      expires_at: 30.days.from_now
    })
  end
end
