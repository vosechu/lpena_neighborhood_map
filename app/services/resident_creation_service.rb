class ResidentCreationService
  def self.create_resident(params, inviter = nil)
    # Convert ActionController::Parameters to hash if needed
    params = params.to_h if params.respond_to?(:to_h)

    # Set first_seen_at if not provided
    params[:first_seen_at] ||= Time.current

    # If official_name not supplied, default to display_name
    params[:official_name] ||= params[:display_name]

    # Create the resident
    resident = Resident.new(params)

    if resident.save
      # Create user if email is provided
      if resident.email.present?
        create_user_for_resident(resident, inviter)
      end

      Rails.logger.info "Resident #{resident.id} created"
      resident
    else
      Rails.logger.warn "Failed to create resident: #{resident.errors.full_messages}"
      resident
    end
  end

  private

  def self.create_user_for_resident(resident, inviter = nil)
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
      ResidentMailer.welcome_new_user(resident, user, inviter).deliver_later

      Rails.logger.info "Created user #{user.id} for resident #{resident.id}"
      user
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create user for resident #{resident.id}: #{e.message}"
      nil
    end
  end
end
