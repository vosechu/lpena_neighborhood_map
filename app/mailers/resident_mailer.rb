class ResidentMailer < ApplicationMailer
  default from: 'noreply@neighborhoodmap.local'

  def welcome_new_user(resident, user, invited_by_user)
    @resident = resident
    @user = user
    @invited_by_user = invited_by_user
    @login_token = UserCreationService.generate_initial_login_token(@user)
    @login_url = edit_user_password_url(reset_password_token: @login_token)

    mail(
      to: @user.email,
      subject: "Welcome to the Neighborhood Map - You've been added by #{@invited_by_user.name}"
    )
  end

  def data_change_notification(resident, changes, updated_by_user)
    @resident = resident
    @changes = changes
    @updated_by_user = updated_by_user
    @opt_out_url = opt_out_url(token: generate_opt_out_token(@resident))

    mail(
      to: @resident.email,
      subject: 'Your neighborhood information has been updated'
    )
  end

  private

  def generate_opt_out_token(resident)
    # Generate a secure token for opt-out functionality
    # This could be improved with a proper token system
    Rails.application.message_verifier(:opt_out).generate({
      resident_id: resident.id,
      expires_at: 30.days.from_now
    })
  end
end
