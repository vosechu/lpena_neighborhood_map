# frozen_string_literal: true

require 'csv'

namespace :import do
  desc 'Import residents and houses from legacy CSV'
  task legacy_residents: :environment do
    csv_path = Rails.root.join('cc_export_cleaned.csv')

    created_count = 0
    updated_count = 0
    error_count = 0

    CSV.foreach(csv_path, headers: true) do |row|
      normalized = normalize_row(row)
      next if normalized.blank?

      case classify_row(normalized)
      when :single_resident
        created, updated = process_single_resident(normalized)
        created_count += created
        updated_count += updated
      when :multiple_residents
        created, updated = process_multiple_residents(normalized)
        created_count += created
        updated_count += updated
      when :contact_info_only
        process_contact_info_only(normalized)
      when :household_members_list
        process_household_members_list(normalized)
      when :nonstandard_address
        log_problematic_row(normalized, 'Nonstandard address')
        error_count += 1
      else
        # Do nothing
      end
      puts '=' * 80
    end

    puts 'Import complete!'
    puts "Residents created: #{created_count}"
    puts "Residents updated: #{updated_count}"
    puts "Errors/problematic rows: #{error_count}"
  end

  # Normalize and clean up a CSV row for easier processing
  def normalize_row(row)
    # Only apply .presence to official names, .strip.presence to all other fields
    fields = row.to_h.transform_values.with_index { |v, i|
      key = row.headers[i]
      if key == 'Owner 1 official name' || key == 'Owner 2 official name'
        v.presence
      else
        v&.strip.presence
      end
    }
    address = fields['Address']
    street_number = nil
    street_name = nil
    if address && address =~ /^\s*(\d+)\s+(.+)$/
      street_number = Regexp.last_match(1).to_i
      street_name = Regexp.last_match(2)
    end

    # Use explicit official and display name columns
    official_names = [ fields['Owner 1 official name'], fields['Owner 2 official name'] ].compact.reject(&:blank?).map(&:upcase)
    display_names = [ fields['Owner 1 display name'], fields['Owner 2 display name'] ].compact.reject(&:blank?)

    emails = [ fields['Owner 1 Email'], fields['Owner 2 Email'] ].compact.reject(&:blank?)
    phones = [ fields['Owner 1 Phone number'], fields['Owner 2 phone number'] ].compact.reject(&:blank?)
    household_members = fields['Household members']&.split(',')&.map(&:strip)&.reject(&:blank?) || []
    homepage = fields['Homepage']
    if homepage.present?
      homepage = homepage.strip.downcase
      homepage = nil if homepage == 'n/a' || homepage == 'none'
      if homepage && !homepage.start_with?('http://', 'https://')
        homepage = "https://#{homepage}"
      end
      # Basic URL validation (very loose, but catches most issues)
      unless homepage =~ /\Ahttps?:\/\/[a-z0-9\.\-]+\.[a-z]{2,}.*\z/
        homepage = nil
      end
    end

    skills = fields['Skills you can share']
    comments = fields['Comments']

    # If all relevant fields are blank, treat as empty row
    if official_names.blank? && emails.blank? && phones.blank? && household_members.blank? &&
       street_number.nil? && street_name.nil? && homepage.blank? && skills.blank? && comments.blank?
      return nil
    end

    {
      street_number: street_number,
      street_name: street_name,
      official_names: official_names,
      display_names: display_names,
      emails: emails,
      phones: phones,
      household_members: household_members,
      homepage: homepage,
      skills: skills,
      comments: comments,
      raw: fields
    }
  end

  # Classify the row into a use case symbol
  def classify_row(row)
    # Blank or incomplete row
    if row[:official_names].blank? && row[:emails].blank? && row[:phones].blank?
      return :blank_or_incomplete
    end
    # Multiple residents
    if row[:official_names].length > 1
      return :multiple_residents
    end
    # Single resident
    if row[:official_names].length == 1
      return :single_resident
    end
    # Household members list but no names
    if row[:official_names].empty? && row[:household_members].present?
      return :household_members_list
    end
    # Contact info only (no names, but emails or phones present)
    if row[:official_names].empty? && (row[:emails].present? || row[:phones].present?)
      return :contact_info_only
    end

    # Fallback
    :unclassified
  end

  # Handle single resident rows
  def process_single_resident(row)
    house = House.find_by(street_number: row[:street_number], street_name: row[:street_name])
    unless house
      log_problematic_row(row, 'House not found for single resident')
      return [ 0, 0 ]
    end

    official_name = row[:official_names].first
    display_name = row[:display_names].first
    email = row[:emails].first
    phone = row[:phones].first
    homepage = row[:homepage]
    skills = row[:skills]
    comments = row[:comments]
    resident = house.residents.find_by(official_name: official_name)
    if resident
      resident.display_name = display_name if display_name.present?
      resident.email = email if email.present?
      resident.phone = phone if phone.present?
      resident.homepage = homepage if homepage.present? && resident.respond_to?(:homepage)
      resident.skills = skills if skills.present?
      resident.comments = comments if comments.present?
      if resident.changed?
        resident.save!
        puts "Updated resident: #{resident.official_name} at #{house.street_number} #{house.street_name}"
        [ 0, 1 ]
      else
        [ 0, 0 ]
      end
    else
      new_resident = Resident.create!(
        house: house,
        official_name: official_name,
        display_name: display_name,
        email: email,
        phone: phone,
        homepage: homepage,
        skills: skills,
        comments: comments,
        first_seen_at: Time.current
      )
      puts "Created new resident: #{official_name} at #{house.street_number} #{house.street_name}"
      [ 1, 0 ]
    end
  end

  # Handle multiple resident rows
  def process_multiple_residents(row)
    house = House.find_by(street_number: row[:street_number], street_name: row[:street_name])
    unless house
      log_problematic_row(row, 'House not found for multiple residents')
      return [ 0, 0 ]
    end

    created_count = 0
    updated_count = 0
    row[:official_names].each_with_index do |official_name, idx|
      # Initialize all fields to nil
      display_name, email, phone, homepage, skills, comments = nil, nil, nil, nil, nil, nil

      # Pull other fields for this resident
      display_name = row[:display_names][idx]
      email = row[:emails][idx]
      phone = row[:phones][idx]

      # Only add comments, homepage, skills to the first resident for this house
      # because the csv doesn't specify which resident these values are for.
      if idx == 0
        homepage = row[:homepage]
        skills = row[:skills]
        comments = row[:comments]
      end

      # Find and update or create the resident
      resident = house.residents.find_by(official_name: official_name)
      if resident
        resident.display_name = display_name if display_name.present?
        resident.email = email if email.present?
        resident.phone = phone if phone.present?
        resident.homepage = homepage if homepage.present? && resident.respond_to?(:homepage)
        resident.skills = skills if skills.present?
        resident.comments = comments if comments.present?
        if resident.changed?
          resident.save!
          puts "Updated resident: #{resident.official_name} at #{house.street_number} #{house.street_name}"
          updated_count += 1
        end
      else
        new_resident = Resident.create!(
          house: house,
          official_name: official_name,
          display_name: display_name,
          email: email,
          phone: phone,
          homepage: homepage,
          skills: skills,
          comments: comments,
          first_seen_at: Time.current
        )
        puts "Created new resident: #{official_name} at #{house.street_number} #{house.street_name}"
        created_count += 1
      end
    end

    [ created_count, updated_count ]
  end

  # Handle rows with only contact info
  def process_contact_info_only(row)
    # TODO: Implement logic for contact-info-only rows
    puts "Would process contact info only: \\#{row.inspect}"
  end

  # Handle rows where household members field is a list
  def process_household_members_list(row)
    # TODO: Implement logic for household members list
    puts "Would process household members list: \\#{row.inspect}"
  end

  # Log or export problematic/ambiguous rows for manual review
  def log_problematic_row(row, reason)
    puts "Problematic row (#{reason}): \\#{row.inspect}"
  end
end
