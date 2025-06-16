class DownloadPropertyDataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting property data download job'
    start_time = Time.current
    stats = { created: 0, updated: 0, unchanged: 0, errors: 0 }

    begin
      connection = Connections::PcpaGisConnection.new
      Rails.logger.info 'Fetching properties from PCPA GIS service...'
      data = connection.fetch_properties

      process_houses(data['features'], stats)

      duration = Time.current - start_time
      Rails.logger.info 'Job Summary:'
      Rails.logger.info "- Total properties processed: #{data['features'].size}"
      Rails.logger.info "- Houses created: #{stats[:created]}"
      Rails.logger.info "- Houses updated: #{stats[:updated]}"
      Rails.logger.info "- Houses unchanged: #{stats[:unchanged]}"
      Rails.logger.info "- Errors encountered: #{stats[:errors]}"
      Rails.logger.info "Successfully processed #{data['features'].size} properties in #{duration.round(2)} seconds"
    rescue StandardError => e
      duration = Time.current - start_time
      Rails.logger.error "Error in DownloadPropertyDataJob after #{duration.round(2)} seconds: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    ensure
      Rails.logger.info "Download job finished in #{(Time.current - start_time).round(2)} seconds"
    end
  end

  private

  def process_houses(houses, stats)
    ActiveRecord::Base.transaction do
      houses.each do |house_details|
        attrs = house_details['attributes']
        pcpa_uid = attrs['PCPA_UID']

        begin
          Rails.logger.info "Processing house #{pcpa_uid} (#{attrs['SITE_ADDR']})"

          # Import house and get reference
          house = HouseImportService.call(house_details)

          if house.saved_changes?
            if house.saved_change_to_id?
              stats[:created] += 1
              Rails.logger.info "Created new house #{pcpa_uid}"
            else
              stats[:updated] += 1
              Rails.logger.info "Updated house #{pcpa_uid}"
              Rails.logger.info "Changes: #{house.saved_changes.except('updated_at').inspect}"
            end
          else
            stats[:unchanged] += 1
          end

          # Always check for ownership changes
          ownership_changes = UpdateHouseOwnershipService.call(
            house: house,
            owner1: attrs['OWNER1'],
            owner2: attrs['OWNER2']
          )

          if ownership_changes[:residents_added].any?
            stats[:created] += ownership_changes[:residents_added].size
            Rails.logger.info "Added residents: #{ownership_changes[:residents_added].map(&:official_name).join(', ')}"
          end
          if ownership_changes[:residents_removed].any?
            stats[:updated] += ownership_changes[:residents_removed].size
            Rails.logger.info "Marked residents as moved out: #{ownership_changes[:residents_removed].map(&:official_name).join(', ')}"
          end
        rescue StandardError => e
          stats[:errors] += 1
          Rails.logger.error "Error processing house #{pcpa_uid}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end
  end
end
