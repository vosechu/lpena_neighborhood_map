class OptOutsController < ApplicationController
  skip_before_action :authenticate_user! # Allow access without login
  before_action :verify_token

  def show
    # Show opt-out options page
  end

  def hide_from_directory
    if @resident.update(hidden: true)
      @success = 'directory_hidden'
      render :show
    else
      @error = 'Unable to hide from directory. Please try again.'
      render :show
    end
  end

  def form_opt_out_emails
    # Form-based email opt-out from the privacy options page
    if @resident.update(email_notifications_opted_out: true)
      @success = 'emails_opted_out'
      render :show
    else
      @error = 'Unable to opt out from emails. Please try again.'
      render :show
    end
  end

  def one_click_unsubscribe
    # One-click unsubscribe for email clients (Gmail, Outlook, etc.)
    if @resident.update(email_notifications_opted_out: true)
      @success = 'emails_opted_out'
      @quick_unsubscribe = true
      render :show
    else
      @error = 'Unable to unsubscribe. Please try again.'
      render :show
    end
  end

  private

  def verify_token
    begin
      token_data = Rails.application.message_verifier(:opt_out).verify(params[:token])

      # Check if token is expired
      if token_data['expires_at'] && Time.parse(token_data['expires_at']) < Time.current
        @error = 'This opt-out link has expired. Please contact vosechu@gmail.com for assistance.'
        render :show and return
      end

      @resident = Resident.find(token_data['resident_id'])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      @error = 'Invalid opt-out link. Please contact vosechu@gmail.com for assistance.'
      render :show and return
    rescue ActiveRecord::RecordNotFound
      @error = 'Resident not found. Please contact vosechu@gmail.com for assistance.'
      render :show and return
    end
  end
end
