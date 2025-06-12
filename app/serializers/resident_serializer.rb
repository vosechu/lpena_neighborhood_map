class ResidentSerializer
  def initialize(resident)
    @resident = resident
  end

  def as_json(*_args)
    return {} if @resident.hidden?

    info = {}
    info[:id] = @resident.id
    info[:display_name] = @resident.display_name unless @resident.hide_display_name
    info[:official_name] = @resident.official_name
    info[:email] = @resident.email if !@resident.hide_email && @resident.email.present?
    info[:phone] = @resident.phone if !@resident.hide_phone && @resident.phone.present?
    info[:birthdate] = @resident.birthdate if !@resident.hide_birthdate && @resident.birthdate.present?
    info[:welcomed_on] = @resident.welcomed_on if @resident.welcomed_on.present?
    info[:homepage] = @resident.homepage
    info[:skills] = @resident.skills
    info[:comments] = @resident.comments
    info[:hidden] = @resident.hidden
    info[:email_notifications_opted_out] = @resident.email_notifications_opted_out
    info[:first_seen_at] = @resident.first_seen_at
    info
  end
end
