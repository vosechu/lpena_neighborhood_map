# frozen_string_literal: true

namespace :update do
  desc 'Update resident first_seen_at dates based on LATEST_SALE_DSP'
  task resident_first_seen_dates: :environment do
    Rails.logger.info 'Starting resident first_seen_at date update job'
    start_time = Time.current

    begin
      connection = Connections::PcpaGisConnection.new
      Rails.logger.info 'Fetching properties from PCPA GIS service...'
      data = connection.fetch_properties

      updated_count = 0
      skipped_count = 0
      error_count = 0

      data['features'].each do |house_details|
        attrs = house_details['attributes']
        pcpa_uid = attrs['PCPA_UID'].to_s
        latest_sale = attrs['LATEST_SALE_DSP']

        unless latest_sale.present?
          Rails.logger.info "Skipping house #{pcpa_uid} (#{attrs['SITE_ADDR']}): No LATEST_SALE_DSP value"
          next
        end

        # For properties with missing or malformed sale data, try to infer from other data
        if !latest_sale.include?('|') || !latest_sale.split('|').first.strip.include?('/') || latest_sale.split('|').first.strip == '/'
          # Try to use the construction date if available
          year_built = attrs['YEAR_BUILT'].to_i
          if year_built > 0
            Rails.logger.info "Using year built (#{year_built}) as first seen date for #{attrs['SITE_ADDR']} due to missing/malformed sale data"
            first_day = Date.new(year_built, 1, 1)  # Use January 1st of build year
          else
            Rails.logger.warn "Problematic sale data for house #{pcpa_uid} (#{attrs['SITE_ADDR']}): '#{latest_sale}'"
            next
          end
        else
          # Parse the latest sale date (format: "07/24 |          $100")
          # Extract just the date part (MM/YY)
          date_part = latest_sale.split('|').first.strip
          month, year = date_part.split('/')
          unless month.present? && year.present?
            Rails.logger.info "Skipping house #{pcpa_uid} (#{attrs['SITE_ADDR']}): Invalid LATEST_SALE_DSP format '#{latest_sale}'"
            next
          end

          begin
            # Convert month and year to integers and validate
            month_num = month.to_i
            year_num = year.to_i

            # Handle two-digit years: 00-29 are 2000s, 30-99 are 1900s
            year_num = if year_num >= 30
                        1900 + year_num  # 97 becomes 1997
                      else
                        2000 + year_num  # 24 becomes 2024
                      end

            unless (1..12).include?(month_num)
              Rails.logger.info "Skipping house #{pcpa_uid} (#{attrs['SITE_ADDR']}): Invalid month '#{month}' in LATEST_SALE_DSP '#{latest_sale}'"
              next
            end

            unless (1930..2025).include?(year_num)
              Rails.logger.info "Skipping house #{pcpa_uid} (#{attrs['SITE_ADDR']}): Year '#{year_num}' from LATEST_SALE_DSP '#{latest_sale}' is outside valid range (1930-2025)"
              next
            end

            # Get the first day of the month
            first_day = Date.new(year_num, month_num, 1)

            # Ensure the sale date isn't before the house was built
            year_built = attrs['YEAR_BUILT'].to_i
            if year_built > 0 && first_day.year < year_built
              Rails.logger.info "Adjusting sale date from #{first_day} to construction date #{year_built} for #{attrs['SITE_ADDR']}"
              first_day = Date.new(year_built, 1, 1)
            end
          rescue StandardError => e
            Rails.logger.error "Error processing house #{pcpa_uid} (#{attrs['SITE_ADDR']}): #{e.message}"
            error_count += 1
            next
          end
        end

        # Find the house by PCPA_UID
        house = House.find_by(pcpa_uid: pcpa_uid)
        unless house
          Rails.logger.info "Skipping house #{pcpa_uid} (#{attrs['SITE_ADDR']}): Not found in database"
          next
        end

        # Update all residents for this house
        house.residents.each do |resident|
          if resident.first_seen_at.nil?
            resident.update!(first_seen_at: first_day)
            updated_count += 1
            Rails.logger.info "Updated resident #{resident.id} (#{resident.official_name}) first_seen_at from nil to #{first_day}" if should_log_details
          elsif resident.first_seen_at > first_day
            old_date = resident.first_seen_at
            resident.update!(first_seen_at: first_day)
            updated_count += 1
            Rails.logger.info "Updated resident #{resident.id} (#{resident.official_name}) first_seen_at from #{old_date} to #{first_day}" if should_log_details
          else
            skipped_count += 1
            Rails.logger.info "Skipping resident #{resident.id} (#{resident.official_name}): Already has earlier first_seen_at date #{resident.first_seen_at}" if should_log_details
          end
        end
      end

      duration = Time.current - start_time
      Rails.logger.info "Successfully processed #{data['features'].size} properties in #{duration.round(2)} seconds"
      Rails.logger.info "Updated #{updated_count} residents"
      Rails.logger.info "Skipped #{skipped_count} residents (already had earlier first_seen_at)"
      Rails.logger.info "Encountered #{error_count} errors"
    rescue StandardError => e
      duration = Time.current - start_time
      Rails.logger.error "Error in update:resident_first_seen_dates after #{duration.round(2)} seconds: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    ensure
      Rails.logger.info "Update job finished in #{(Time.current - start_time).round(2)} seconds"
    end
  end
end
