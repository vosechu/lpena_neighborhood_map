class ResidentUpdateService
  def self.update_resident(resident, params)
    # Convert ActionController::Parameters to hash if needed
    params = params.to_h if params.respond_to?(:to_h)

    original_attributes = resident.attributes.dup
    original_email = resident.email

    # Update the resident
    if resident.update(params)
      # Handle email changes
      handle_email_change(resident, original_email)

      # Send notification email if resident has email, data changed, and not hidden
      if should_send_notification?(resident, original_attributes)
        send_change_notification(resident, original_attributes)
      end

      Rails.logger.info "Resident #{resident.id} updated"
      true
    else
      Rails.logger.warn "Failed to update resident #{resident.id}: #{resident.errors.full_messages}"
      false
    end
  end

  # Class method to resend welcome email
  def self.resend_welcome_email(resident)
    return false unless resident.user.present? && resident.email.present?

    # Generate a new login token
    login_token = UserCreationService.generate_initial_login_token(resident.user)

    # Send welcome email
    ResidentMailer.welcome_new_user(resident, resident.user).deliver_later

    Rails.logger.info "Resent welcome email to #{resident.email} for resident #{resident.id}"
    true
  rescue => e
    Rails.logger.error "Failed to resend welcome email for resident #{resident.id}: #{e.message}"
    false
  end

  private

  def self.handle_email_change(resident, original_email)
    return if resident.email == original_email # No change

    if resident.email.blank?
      # Email was removed - keep the user association but don't do anything else
      Rails.logger.info "Email removed for resident #{resident.id}, keeping user association"
      return
    end

    if resident.user.present?
      # Resident has a user - update the user's email if it's different
      if resident.user.email != resident.email
        resident.user.update(email: resident.email)
        Rails.logger.info "Updated email for existing user #{resident.user.id} to #{resident.email}"
      end
    else
      # Resident has no user - check if user exists with this email
      existing_user = User.find_by(email: resident.email)
      if existing_user
        # Link existing user to resident
        resident.update(user: existing_user)
        Rails.logger.info "Linked existing user #{existing_user.id} to resident #{resident.id}"
      else
        # Create new user
        create_user_for_resident(resident)
      end
    end
  end

  def self.create_user_for_resident(resident)
    return if resident.email.blank?

    begin
      user = UserCreationService.create_user(
        email: resident.email,
        name: resident.display_name.presence || resident.official_name,
        role: 'user'
      )

      # Link user to resident
      resident.update(user: user)

      # Send welcome email with login instructions
      ResidentMailer.welcome_new_user(resident, user).deliver_later

      Rails.logger.info "Created user #{user.id} for resident #{resident.id}"
      user
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create user for resident #{resident.id}: #{e.message}"
      nil
    end
  end

  def self.should_send_notification?(resident, original_attributes)
    return false if resident.email.blank?
    return false if resident.hidden?

    # Check if any displayable fields changed (including email)
    changed_fields = %w[display_name phone email homepage skills comments].select do |field|
      original_attributes[field] != resident.attributes[field]
    end

    changed_fields.any?
  end

  def self.send_change_notification(resident, original_attributes)
    # Determine what changed
    changes = {}
    %w[display_name phone email homepage skills comments].each do |field|
      if original_attributes[field] != resident.attributes[field]
        changes[field] = {
          from: original_attributes[field],
          to: resident.attributes[field]
        }
      end
    end

    return if changes.empty?

    # Send notification email
    ResidentMailer.data_change_notification(resident, changes).deliver_later

    Rails.logger.info "Sent change notification to #{resident.email} for resident #{resident.id}"
  end
end
