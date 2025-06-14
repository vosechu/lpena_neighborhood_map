class ResidentSerializer
  def initialize(resident, current_user: nil)
    @resident = resident
    @current_user = current_user
  end

  def can_view_hidden?
    # Only the resident owner can see their own hidden data
    return true if @current_user && @resident.user_id == @current_user.id
    false
  end

  def as_json(*_args)
    return {} if @resident.hidden? && !can_view_hidden?

    info = {}
    info[:id] = @resident.id
    info[:user_id] = @resident.user_id
    if (@resident.hidden? || @resident.hide_display_name) && !can_view_hidden?
      info[:display_name] = '(hidden by user)'
    else
      info[:display_name] = @resident.display_name if @resident.display_name.present?
    end
    info[:hide_display_name] = @resident.hide_display_name
    info[:official_name] = @resident.official_name
    if (@resident.hidden? || @resident.hide_email) && !can_view_hidden?
      info[:email] = '(hidden by user)'
    else
      info[:email] = @resident.email if @resident.email.present?
    end
    info[:hide_email] = @resident.hide_email
    if (@resident.hidden? || @resident.hide_phone) && !can_view_hidden?
      info[:phone] = '(hidden by user)'
    else
      info[:phone] = @resident.phone if @resident.phone.present?
    end
    info[:hide_phone] = @resident.hide_phone
    if (@resident.hidden? || @resident.hide_birthdate) && !can_view_hidden?
      info[:birthdate] = '(hidden by user)'
    else
      info[:birthdate] = @resident.birthdate if @resident.birthdate.present?
    end
    info[:hide_birthdate] = @resident.hide_birthdate
    info[:homepage] = @resident.homepage
    info[:skills] = @resident.skills
    info[:comments] = @resident.comments
    info[:hidden] = @resident.hidden
    info[:email_notifications_opted_out] = @resident.email_notifications_opted_out
    info[:welcomed_on] = @resident.welcomed_on if @resident.welcomed_on.present?
    info[:first_seen_at] = @resident.first_seen_at
    info
  end
end
