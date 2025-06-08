class DownloadPropertyDataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting property data download job'
    start_time = Time.current
    conflict_manager = DataConflictManager.new

    begin
      connection = Connections::PcpaGisConnection.new
      Rails.logger.info 'Fetching properties from PCPA GIS service...'
      data = connection.fetch_properties

      process_houses(data['features'], conflict_manager)

      duration = Time.current - start_time
      Rails.logger.info "Successfully processed #{data['features'].size} properties in #{duration.round(2)} seconds"
      
      # Send admin notification if conflicts were detected
      if conflict_manager.has_conflicts?
        Rails.logger.warn "Sending admin notification for #{conflict_manager.conflicts.length} conflicts"
        send_conflict_notification(conflict_manager, duration)
      else
        Rails.logger.info "No conflicts detected during this import"
      end

      # Log final summary
      summary = conflict_manager.summary
      Rails.logger.info "Import summary: #{summary.to_json}"

    rescue StandardError => e
      duration = Time.current - start_time
      error_message = "#{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      Rails.logger.error "Error in DownloadPropertyDataJob after #{duration.round(2)} seconds: #{error_message}"
      
      # Send failure notification
      send_failure_notification(error_message, duration)
      
      raise e
    ensure
      Rails.logger.info "Download job finished in #{(Time.current - start_time).round(2)} seconds"
    end
  end

  private

  def process_houses(houses, conflict_manager)
    ActiveRecord::Base.transaction do
      houses.each do |house_details|
        attrs = house_details['attributes']

        # Import house and detect conflicts
        house = HouseImportService.call(house_details)
        
        # Check for house-related conflicts
        if house.persisted? && house.previous_changes.any?
          conflict_manager.detect_and_resolve_house_conflicts(house, attrs)
        end

        # Update ownership if house was created or updated and detect ownership conflicts
        if house.saved_changes?
          # Check for ownership conflicts before making changes
          ownership_conflicts = conflict_manager.detect_ownership_conflicts(
            house, 
            attrs['OWNER1'], 
            attrs['OWNER2']
          )
          
          # Log ownership conflicts
          if ownership_conflicts.any?
            Rails.logger.warn "Ownership conflict detected for house #{house.id}: #{ownership_conflicts.first[:type]}"
          end

          # Apply the ownership update (with latest data wins strategy)
          UpdateHouseOwnershipService.call(
            house: house,
            owner1: attrs['OWNER1'],
            owner2: attrs['OWNER2']
          )
        end
      end
    end
  end

  def send_conflict_notification(conflict_manager, duration)
    AdminNotificationMailer.data_conflict_notification(
      conflict_manager.conflicts,
      conflict_manager.summary,
      duration
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error "Failed to send conflict notification email: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def send_failure_notification(error_message, duration)
    AdminNotificationMailer.job_failure_notification(
      error_message,
      duration
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error "Failed to send failure notification email: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
