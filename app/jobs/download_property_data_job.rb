class DownloadPropertyDataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting property data download job'
    start_time = Time.current

    begin
      connection = Connections::PcpaGisConnection.new
      Rails.logger.info 'Fetching properties from PCPA GIS service...'
      data = connection.fetch_properties

      process_houses(data['features'])

      duration = Time.current - start_time
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

  def process_houses(houses)
    ActiveRecord::Base.transaction do
      houses.each do |house_details|
        attrs = house_details['attributes']

        # Import house and get reference
        house = HouseImportService.call(house_details)

        # Update ownership if house was created or updated
        if house.saved_changes?
          UpdateHouseOwnershipService.call(
            house: house,
            owner1: attrs['OWNER1'],
            owner2: attrs['OWNER2']
          )
        end
      end
    end
  end
end
