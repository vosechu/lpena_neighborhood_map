class DownloadPropertyDataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting property data download job'
    start_time = Time.current
    stats = { created: 0, updated: 0, unchanged: 0, errors: 0, skipped: 0 }

    begin
      Rails.logger.info 'Fetching properties from PCPA GIS service...'
      connection = Connections::PcpaGisConnection.new
      data = connection.fetch_properties
    rescue StandardError => e
      Rails.logger.error "Error fetching properties from PCPA GIS service: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end

    data['features'].each do |house_details|
      attrs = house_details['attributes']

      # Skip apartment buildings in the denylist
      if ApartmentDenylistService.should_skip?(house_details)
        stats[:skipped] += 1
        Rails.logger.info "Skipping apartment building: #{attrs['SITE_ADDR']}"
        next
      end

      begin
        # Import house and get reference
        house = HouseImportService.call(house_details)

        # Check for ownership changes
        UpdateHouseOwnershipService.new(
          house: house,
          owner1_name: attrs['OWNER1'],
          owner2_name: attrs['OWNER2']
        ).call
      rescue StandardError => e
        stats[:errors] += 1
        Rails.logger.error "Error processing house at #{attrs['SITE_ADDR']}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    Rails.logger.info "Job completed. Stats: #{stats}"
  end
end
