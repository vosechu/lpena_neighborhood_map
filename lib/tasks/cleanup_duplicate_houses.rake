# frozen_string_literal: true

module HouseCleanupHelper
  def self.deduplicate_residents_on_house(house)
    # Find duplicate residents by official_name
    duplicates = Resident.where(house_id: house.id)
                      .group(:official_name)
                      .having('COUNT(*) > 1')
                      .count

    duplicates.each do |official_name, count|
      residents = Resident.where(house_id: house.id)
                       .where(official_name: official_name)
                       .order(:created_at)

      # Keep the oldest resident, mark others as moved out
      oldest_resident = residents.first
      duplicates_to_remove = residents.where.not(id: oldest_resident.id)

      puts "    Deduplicating residents with name '#{official_name}':"
      puts "      Keeping: ID #{oldest_resident.id} (created: #{oldest_resident.created_at})"

      duplicates_to_remove.each do |resident|
        resident.update!(moved_out_at: Time.current)
        puts "      Marked as moved out: ID #{resident.id} (created: #{resident.created_at})"
      end
    end
  end
end

namespace :houses do
  desc 'Clean up duplicate houses by address'
  task cleanup_duplicates: :environment do
    # Turn off AR::B logging
    Rails.logger.level = Logger::ERROR
    Rails.application.config.active_record.verbose_query_logs = false
    ActiveRecord::Base.logger.level = Logger::ERROR if ActiveRecord::Base.logger.present?

    puts '=== House Duplicate Cleanup ==='

    # Find duplicates by address
    duplicates = House.group(:street_number, :street_name, :city)
                     .having('COUNT(*) > 1')
                     .count

    if duplicates.empty?
      puts 'No duplicate houses found by address.'
      next
    end

    puts "Found #{duplicates.size} groups of duplicate houses:"
    total_removed = 0

    duplicates.each do |(street_number, street_name, city), count|
      houses = House.where(street_number: street_number,
                          street_name: street_name,
                          city: city)
                    .order(:created_at)
                    .includes(:residents)

      # Keep the oldest house, mark others for deletion
      oldest_house = houses.first
      duplicates_to_remove = houses.where.not(id: oldest_house.id)

      puts "\nAddress: #{street_number} #{street_name}, #{city}"
      puts "  Keeping: ID #{oldest_house.id} (PCPA_UID: #{oldest_house.pcpa_uid}, created: #{oldest_house.created_at})"
      puts "  Removing: #{duplicates_to_remove.count} duplicates"

      # Move residents from duplicate houses to the oldest house
      duplicates_to_remove.each do |house|
        Resident.where(house_id: house.id).each do |new_resident|
          # Check that a resident with the same official_name doesn't already exist
          existing_resident = Resident.find_by(house_id: oldest_house.id, official_name: new_resident.official_name)
          if existing_resident.present?
            # Unless this resident has some additional details that are different
            if (new_resident.birthdate.present? && new_resident.birthdate.strip != existing_resident.birthdate&.strip) ||
              (new_resident.email.present? && new_resident.email.strip != existing_resident.email&.strip) ||
              (new_resident.phone.present? && new_resident.phone.strip != existing_resident.phone&.strip) ||
              (new_resident.homepage.present? && new_resident.homepage.strip != existing_resident.homepage&.strip) ||
              (new_resident.skills.present? && new_resident.skills.strip != existing_resident.skills&.strip) ||
              (new_resident.comments.present? && new_resident.comments.strip != existing_resident.comments&.strip)

              puts "    Resident #{new_resident.id} (#{new_resident.official_name}) already exists on house #{oldest_house.id} with different details:"
              puts "      new: #{ResidentSerializer.new(new_resident).as_json}"
              puts "      existing: #{ResidentSerializer.new(existing_resident).as_json}"

              new_resident.update!(house: oldest_house)
            else
              print 'd'
              new_resident.destroy!
            end
          else
            new_resident.update!(house: oldest_house)
            print 'm'
          end
        end
      end

      # Deduplicate residents on the oldest house after moving them
      HouseCleanupHelper.deduplicate_residents_on_house(oldest_house)

      # Check that there's at least some residents on the oldest house and if not,
      # clear moved_out_at for the newest residents that have a similar creation date
      if oldest_house.residents.count == 0
        # Find residents that were moved to this house (they have moved_out_at set)
        # and clear their moved_out_at to make them active again
        # Only reactivate residents with similar moved_out_at dates (within 1 minute of each other)
        moved_out_residents = oldest_house.residents.where.not(moved_out_at: nil).order(moved_out_at: :desc)

        if moved_out_residents.any?
          # Get the most recent moved_out_at time as reference (newest residents first)
          reference_time = moved_out_residents.first.moved_out_at

          # Find all residents moved out within 1 minute of the reference time
          similar_residents = moved_out_residents.where(
            'moved_out_at BETWEEN ? AND ?',
            reference_time - 1.minute,
            reference_time + 1.minute
          )

          similar_residents.each do |resident|
            resident.update!(moved_out_at: nil)
          end
        end
      end

      # Delete the duplicate houses (now that all residents are moved)
      duplicates_to_remove.destroy_all
      total_removed += duplicates_to_remove.count
    end

    puts "\n=== Summary ==="
    puts "Total duplicate houses removed: #{total_removed}"
    puts "Remaining houses: #{House.count}"
  end

  desc 'Show duplicate houses by address'
  task list_duplicates: :environment do
    puts '=== Duplicate Houses by Address ==='

    duplicates = House.group(:street_number, :street_name, :city)
                     .having('COUNT(*) > 1')
                     .count

    if duplicates.empty?
      puts 'No duplicate houses found.'
      return
    end

    duplicates.each do |(street_number, street_name, city), count|
      houses = House.where(street_number: street_number,
                          street_name: street_name,
                          city: city)
                    .order(:created_at)

      puts "\n#{street_number} #{street_name}, #{city} (#{count} houses):"
      houses.each do |house|
        resident_count = house.residents.count
        puts "  ID: #{house.id}, PCPA_UID: #{house.pcpa_uid}, Residents: #{resident_count}, Created: #{house.created_at}"
      end
    end
  end

  desc 'Reactivate residents on houses with no active residents'
  task reactivate_residents: :environment do
    # Turn off AR::B logging
    Rails.logger.level = Logger::ERROR
    ActiveRecord::Base.logger.level = Logger::ERROR if ActiveRecord::Base.logger.present?

    puts '=== Reactivate Residents on Empty Houses ==='

    # Find houses with no active residents
    houses_without_residents = House.includes(:residents).select do |house|
      house.residents.count == 0
    end

    if houses_without_residents.empty?
      puts 'No houses found without active residents.'
      next
    end

    puts "Found #{houses_without_residents.size} houses without active residents:"
    total_reactivated = 0

    houses_without_residents.each do |house|
      puts "\nAddress: #{house.street_number} #{house.street_name}, #{house.city}"
      puts "  House ID: #{house.id} (PCPA_UID: #{house.pcpa_uid})"

      # Gather all moved-out residents BEFORE any updates
      moved_out_residents = Resident.where(house_id: house.id).where.not(moved_out_at: nil).order(moved_out_at: :desc)

      if moved_out_residents.any?
        reference_time = moved_out_residents.first.moved_out_at
        similar_residents = moved_out_residents.where(
          'moved_out_at BETWEEN ? AND ?',
          reference_time - 1.minute,
          reference_time + 1.minute
        )

        puts "  Reactivating #{similar_residents.count} residents with similar moved_out_at dates:"
        # Reactivate ALL similar residents in one pass
        similar_residents.each do |resident|
          begin
            resident.update!(moved_out_at: nil)
            puts "    - #{resident.official_name} (moved_out_at was: #{resident.moved_out_at_was})"
            total_reactivated += 1
          rescue => e
            puts "    ERROR updating #{resident.official_name}: #{e.class} - #{e.message}"
          end
        end
      else
        puts "  No residents with moved_out_at found for this house."
      end
    end

    puts "\n=== Summary ==="
    puts "Total residents reactivated: #{total_reactivated}"
  end
end
