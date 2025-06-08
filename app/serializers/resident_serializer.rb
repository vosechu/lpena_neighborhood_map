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
    info[:subscribed] = @resident.subscribed?
    info[:first_seen_at] = @resident.first_seen_at
    info[:is_new] = @resident.first_seen_at > 30.days.ago
    info[:house] = {
      id: @resident.house.id,
      address: "#{@resident.house.street_number} #{@resident.house.street_name}, #{@resident.house.city}, #{@resident.house.state} #{@resident.house.zip}",
      street_number: @resident.house.street_number,
      street_name: @resident.house.street_name,
      city: @resident.house.city,
      state: @resident.house.state,
      zip: @resident.house.zip
    }
    info
  end
end
