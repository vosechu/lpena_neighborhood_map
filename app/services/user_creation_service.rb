class UserCreationService
  def self.create_user(email:, name:, role: 'user', send_invitation: true)
    # Generate a random password
    password = SecureRandom.alphanumeric(12)

    user = User.create!(
      email: email,
      name: name,
      role: role,
      password: password,
      password_confirmation: password
    )

    if send_invitation && user.persisted?
      # TODO: Send invitation email with magic login link
      # This could be implemented later with a mailer that sends
      # a password reset token that also sets up the account
      Rails.logger.info "User created: #{user.email} (password: #{password})"
    end

    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create user: #{e.message}"
    raise e
  end

  # Create a temporary password reset token for initial login
  def self.generate_initial_login_token(user)
    raw_token = user.send(:set_reset_password_token)
    Rails.logger.info "Initial login token for #{user.email}: #{raw_token}"
    raw_token
  end
end
