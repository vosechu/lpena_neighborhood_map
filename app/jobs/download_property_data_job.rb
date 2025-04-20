class DownloadPropertyDataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting property data download job"

    begin
      connection = Connections::PcpaGisConnection.new
      data = connection.fetch_properties

      # TODO: Store the processed data in the database
      # This is where we'll implement the database storage logic
      # For now, we'll just log the number of properties found
      Rails.logger.info "Successfully downloaded #{data['features'].size} properties"

      # Return the cleaned data for now
      data
    rescue StandardError => e
      Rails.logger.error "Error in DownloadPropertyDataJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end
end
