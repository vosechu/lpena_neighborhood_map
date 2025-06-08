class ResidentUpdateService
  def self.update_resident(resident, params)
    # Convert ActionController::Parameters to hash if needed
    params = params.to_h if params.respond_to?(:to_h)

    original_attributes = resident.attributes.dup
    original_email = resident.email

    # Update the resident
    if resident.update(params)
      # Check if email was added and create user if needed
      if email_was_added?(original_email, resident.email)
        create_user_for_resident(resident)
      end

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

  private

  def self.email_was_added?(original_email, new_email)
    original_email.blank? && new_email.present?
  end

  def self.create_user_for_resident(resident)
    return if resident.email.blank?

    # Check if user already exists with this email
    existing_user = User.find_by(email: resident.email)
    if existing_user
      # Link existing user to resident if not already linked
      if resident.user.nil?
        resident.update(user: existing_user)
        Rails.logger.info "Linked existing user #{existing_user.id} to resident #{resident.id}"
      end
      return existing_user
    end

    # Create new user
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
