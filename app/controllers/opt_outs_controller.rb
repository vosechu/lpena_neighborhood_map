class OptOutsController < ApplicationController
  skip_before_action :authenticate_user! # Allow access without login
  before_action :verify_token

  def show
    # Show opt-out confirmation page
  end

  def create
    if @resident.update(email_notifications_opted_out: true)
      @success = true
      render :show
    else
      @error = "Unable to process opt-out request. Please try again."
      render :show
    end
  end

  private

  def verify_token
    begin
      token_data = Rails.application.message_verifier(:opt_out).verify(params[:token])
      
      # Check if token is expired
      if token_data['expires_at'] && Time.parse(token_data['expires_at']) < Time.current
        @error = "This opt-out link has expired. Please contact us directly."
        render :show and return
      end
      
      @resident = Resident.find(token_data['resident_id'])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      @error = "Invalid opt-out link. Please contact us directly."
      render :show and return
    rescue ActiveRecord::RecordNotFound
      @error = "Resident not found. Please contact us directly."
      render :show and return
    end
  end
end