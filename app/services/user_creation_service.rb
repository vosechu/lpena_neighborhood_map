class UserCreationService
  def self.create_user(email:, name:, role: 'user')
    # Create user without password - they'll set it via password reset
    user = User.new(
      email: email,
      name: name,
      role: role
    )

    # Skip password validation for initial creation
    user.save!(validate: false)

    Rails.logger.info "User created: #{user.email} (will set password via reset token)"
    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create user: #{e.message}"
    raise e
  end

  # Create a password reset token for initial login
  def self.generate_initial_login_token(user)
    raw_token = user.send(:set_reset_password_token)
    Rails.logger.info "Initial login token generated for #{user.email}"
    raw_token
  end
end
