# frozen_string_literal: true

namespace :houses do
  desc 'Clean up duplicate houses by address'
  task cleanup_duplicates: :environment do
    # Turn off AR::B logging
    Rails.logger.level = Logger::ERROR
    Rails.application.config.active_record.verbose_query_logs = false
    ActiveRecord::Base.logger.level = Logger::ERROR if ActiveRecord::Base.logger.present?

    puts '=== Restore from Backup Date (2025-06-17 03:59:00 UTC) ==='

    cutoff_time = Time.parse('2025-06-17 03:59:00 UTC')
    puts "Cutoff time: #{cutoff_time}"

    # Define a reactivation window around the cutoff time (few hours before and after)
    reactivation_window = 3.hours
    reactivation_start = cutoff_time - reactivation_window
    reactivation_end = cutoff_time + reactivation_window
    puts "Reactivation window: #{reactivation_start} to #{reactivation_end}"

    # Step 1: Find all houses with duplicates
    duplicates = House.group(:street_number, :street_name, :city)
                     .having('COUNT(*) > 1')
                     .count

    puts "Found #{duplicates.size} groups of duplicate houses"
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

      # Move residents from duplicate houses to the oldest house
      duplicates_to_remove.each do |house|
        Resident.where(house_id: house.id).each do |new_resident|
          # Check that a resident with the same official_name doesn't already exist
          existing_resident = Resident.find_by(house_id: oldest_house.id, official_name: new_resident.official_name)
          if existing_resident.present?
            # Only compare meaningful fields, not all serializer fields
            existing_data = {
              user_id: existing_resident.user_id,
              email: existing_resident.email,
              phone: existing_resident.phone,
              birthdate: existing_resident.birthdate,
              homepage: existing_resident.homepage,
              skills: existing_resident.skills,
              comments: existing_resident.comments,
              hide_email: existing_resident.hide_email,
              hide_phone: existing_resident.hide_phone,
              hide_birthdate: existing_resident.hide_birthdate,
              hide_display_name: existing_resident.hide_display_name
            }

            new_data = {
              user_id: new_resident.user_id,
              email: new_resident.email,
              phone: new_resident.phone,
              birthdate: new_resident.birthdate,
              homepage: new_resident.homepage,
              skills: new_resident.skills,
              comments: new_resident.comments,
              hide_email: new_resident.hide_email,
              hide_phone: new_resident.hide_phone,
              hide_birthdate: new_resident.hide_birthdate,
              hide_display_name: new_resident.hide_display_name
            }

            # Check if new resident has additional data that existing doesn't have
            has_additional_data = false
            additional_fields = []

            new_data.each do |field, new_value|
              existing_value = existing_data[field]
              if existing_value.blank? && new_value.present?
                has_additional_data = true
                additional_fields << field
              end
            end

            if has_additional_data
              puts '--------------------------------'
              puts "    Resident #{new_resident.id} (#{new_resident.official_name}) already exists on house #{oldest_house.id} with additional data:"
              puts "      Additional fields: #{additional_fields.join(', ')}"

              # Also show the full diff for context
              puts "      Existing data: #{existing_data.inspect}"
              puts "      New data: #{new_data.inspect}"
              puts '--------------------------------'

              # Track for manual review instead of auto-resolving
              @manual_review_cases ||= []
              @manual_review_cases << {
                house: oldest_house,
                existing_resident: existing_resident,
                new_resident: new_resident,
                additional_fields: additional_fields
              }

              # Keep both for now - mark new one as moved out
              new_resident.update!(house: oldest_house, moved_out_at: Time.current)
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

      # Delete the duplicate houses (now that all residents are moved)
      duplicates_to_remove.destroy_all
      total_removed += duplicates_to_remove.count
    end

    puts "\n=== Step 2: Restore residents to state before cutoff time ==="

    # For each house, restore residents to their state before the cutoff time
    House.includes(:residents).find_each do |house|
      # Get all residents for this house
      all_residents = Resident.where(house_id: house.id)

      # Group residents by official_name to handle duplicates
      residents_by_name = all_residents.group_by(&:official_name)

      residents_by_name.each do |official_name, residents|
        if residents.count == 1
          # Single resident - only restore if they were moved out within the reactivation window
          resident = residents.first
          if resident.moved_out_at &&
             resident.moved_out_at >= reactivation_start &&
             resident.moved_out_at <= reactivation_end
            puts "  Restoring single resident: #{resident.official_name} (moved_out_at: #{resident.moved_out_at})"
            resident.update!(moved_out_at: nil)
          end
        else
          # Multiple residents with same name - keep the oldest one that was active before cutoff
          # or the one with the most recent activity after cutoff
          residents_sorted = residents.sort_by(&:created_at)

          # Also find residents moved out within the reactivation window
          residents_in_window = residents_sorted.select do |r|
            r.moved_out_at &&
            r.moved_out_at >= reactivation_start &&
            r.moved_out_at <= reactivation_end
          end

          # Mark others as moved out, but only if they were moved out within the reactivation window
          residents_sorted.each do |resident|
            if resident.moved_out_at &&
                resident.moved_out_at >= reactivation_start &&
                resident.moved_out_at <= reactivation_end
              puts "    Marking as moved out: #{resident.official_name} (moved_out_at: #{resident.moved_out_at})"
              resident.update!(moved_out_at: Time.current)
            end
          end

          if residents_in_window.any?
            # No residents active before cutoff, but some were moved out within the window
            puts "  Reactivating ALL residents in reactivation window for: #{official_name}"
            residents_in_window.each do |resident|
              puts "    Reactivating: #{resident.official_name} (moved_out_at: #{resident.moved_out_at})"
              resident.update!(moved_out_at: nil)
            end
          else
            puts "  No residents found in reactivation window for: #{official_name}"
          end
        end
      end
    end

    puts "\n=== Summary ==="
    puts "Total duplicate houses removed: #{total_removed}"
    puts "Remaining houses: #{House.count}"
    puts "Total active residents: #{Resident.where(moved_out_at: nil).count}"

    # Check that each house has at least some active residents
    puts "\n=== Checking for houses with no active residents ==="
    houses_without_residents = []

    House.includes(:residents).find_each do |house|
      active_residents = house.residents.count
      if active_residents == 0
        houses_without_residents << house
        puts "  WARNING: #{house.street_number} #{house.street_name}, #{house.city} (ID: #{house.id}) has no active residents"
      end
    end

    if houses_without_residents.empty?
      puts '  All houses have at least one active resident ✓'
    else
      puts "  Found #{houses_without_residents.count} houses with no active residents"
    end

    # Check for houses with more than 2 current residents (potential duplicates)
    puts "\n=== Checking for houses with more than 2 current residents ==="
    houses_with_many_residents = []

    House.includes(:residents).find_each do |house|
      active_residents = house.residents.count
      if active_residents > 2
        houses_with_many_residents << house
        puts "  WARNING: #{house.street_number} #{house.street_name}, #{house.city} (ID: #{house.id}) has #{active_residents} active residents"
        house.residents.each do |resident|
          puts "    - #{resident.official_name}"
        end
      end
    end

    if houses_with_many_residents.empty?
      puts '  No houses found with more than 2 active residents ✓'
    else
      puts "  Found #{houses_with_many_residents.count} houses with more than 2 active residents"
    end

    # Report manual review cases
    if @manual_review_cases&.any?
      puts "\n=== Manual Review Required ==="
      puts "Found #{@manual_review_cases.count} cases where duplicate residents have different data:"

      @manual_review_cases.each_with_index do |case_data, index|
        house = case_data[:house]
        existing = case_data[:existing_resident]
        new_resident = case_data[:new_resident]
        additional_fields = case_data[:additional_fields]

        puts "\n  #{index + 1}. #{house.street_number} #{house.street_name}, #{house.city}"
        puts "     Existing: #{existing.official_name} (ID: #{existing.id})"
        puts "     New: #{new_resident.official_name} (ID: #{new_resident.id})"
        puts "     Additional fields: #{additional_fields.join(', ')}"
      end
    else
      puts "\n=== Manual Review Required ==="
      puts 'No manual review cases found ✓'
    end
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
end
