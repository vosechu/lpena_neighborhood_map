class ResidentUpdateService
  def self.update_resident(resident, params, updated_by_user)
    original_attributes = resident.attributes.dup
    original_email = resident.email
    
    # Update the resident
    if resident.update(params)
      # Check if email was added and create user if needed
      user_created = false
      if email_was_added?(original_email, resident.email)
        create_user_for_resident(resident, updated_by_user)
        user_created = true
      end
      
      # Send notification email if resident has email and data changed
      # But don't send change notification if we just created a user (they get a welcome email instead)
      if !user_created && should_send_notification?(resident, original_attributes)
        send_change_notification(resident, original_attributes, updated_by_user)
      end
      
      Rails.logger.info "Resident #{resident.id} updated by user #{updated_by_user.id}"
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

  def self.create_user_for_resident(resident, updated_by_user)
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
        role: 'user',
        send_invitation: false # We'll handle notification separately
      )
      
      # Link user to resident
      resident.update(user: user)
      
      # Send welcome email with login instructions
      ResidentMailer.welcome_new_user(resident, user, updated_by_user).deliver_later
      
      Rails.logger.info "Created user #{user.id} for resident #{resident.id}, invited by user #{updated_by_user.id}"
      user
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create user for resident #{resident.id}: #{e.message}"
      nil
    end
  end

  def self.should_send_notification?(resident, original_attributes)
    return false if resident.email.blank?
    return false if resident.email_notifications_opted_out?
    
    # Check if any displayable fields changed
    changed_fields = %w[display_name phone homepage skills comments].select do |field|
      original_attributes[field] != resident.attributes[field]
    end
    
    changed_fields.any?
  end

  def self.send_change_notification(resident, original_attributes, updated_by_user)
    # Determine what changed
    changes = {}
    %w[display_name phone homepage skills comments].each do |field|
      if original_attributes[field] != resident.attributes[field]
        changes[field] = {
          from: original_attributes[field],
          to: resident.attributes[field]
        }
      end
    end
    
    return if changes.empty?
    
    # Send notification email
    ResidentMailer.data_change_notification(resident, changes, updated_by_user).deliver_later
    
    Rails.logger.info "Sent change notification to #{resident.email} for resident #{resident.id}"
  end
end