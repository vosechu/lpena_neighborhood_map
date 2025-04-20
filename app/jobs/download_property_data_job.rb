class DownloadPropertyDataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting property data download job'
    start_time = Time.current

    begin
      connection = Connections::PcpaGisConnection.new
      Rails.logger.info 'Fetching properties from PCPA GIS service...'
      data = connection.fetch_properties

      # TODO: Store the processed data in the database
      # This is where we'll implement the database storage logic
      # For now, we'll just log the number of properties found
      duration = Time.current - start_time
      Rails.logger.info "Successfully downloaded #{data['features'].size} properties in #{duration.round(2)} seconds"

      # Return the cleaned data for now
      data
    rescue StandardError => e
      duration = Time.current - start_time
      Rails.logger.error "Error in DownloadPropertyDataJob after #{duration.round(2)} seconds: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    ensure
      Rails.logger.info "Download job finished in #{(Time.current - start_time).round(2)} seconds"
    end
  end
end
