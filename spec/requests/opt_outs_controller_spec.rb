require 'rails_helper'

RSpec.describe OptOutsController, type: :request do
  let(:resident) { create(:resident, display_name: 'Test Resident', email: 'test@example.com') }
  let(:token) { generate_opt_out_token(resident) }
  let(:expired_token) { generate_expired_opt_out_token(resident) }
  let(:invalid_token) { 'invalid-token' }

  def generate_opt_out_token(resident)
    Rails.application.message_verifier(:opt_out).generate({
      resident_id: resident.id,
      expires_at: 30.days.from_now
    })
  end

  def generate_expired_opt_out_token(resident)
    Rails.application.message_verifier(:opt_out).generate({
      resident_id: resident.id,
      expires_at: 1.day.ago
    })
  end

  describe 'GET /opt-out/:token' do
    context 'with valid token' do
      it 'shows opt-out options page' do
        get opt_out_path(token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Privacy Options')
        expect(response.body).to include('Test Resident')
        expect(response.body).to include('Stop Email Notifications')
        expect(response.body).to include('Hide from Directory')
      end
    end

    context 'with expired token' do
      it 'shows error message' do
        get opt_out_path(expired_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('This opt-out link has expired')
      end
    end

    context 'with invalid token' do
      it 'shows error message' do
        get opt_out_path(invalid_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Invalid opt-out link')
      end
    end

    context 'with non-existent resident' do
      let(:token_for_missing_resident) do
        Rails.application.message_verifier(:opt_out).generate({
          resident_id: 99999,
          expires_at: 30.days.from_now
        })
      end

      it 'shows error message' do
        get opt_out_path(token_for_missing_resident)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Resident not found')
      end
    end
  end

  describe 'POST /opt-out/:token/opt-out-emails' do
    context 'with valid token' do
      it 'opts resident out of email notifications' do
        expect(resident.email_notifications_opted_out).to be_falsey

        post form_opt_out_emails_path(token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Unsubscribed!')
        expect(response.body).to include('Email Notifications Disabled')

        resident.reload
        expect(resident.email_notifications_opted_out).to be_truthy
        expect(resident.hidden).to be_falsey # Still visible in directory
      end
    end

    context 'with invalid token' do
      it 'shows error message' do
        post form_opt_out_emails_path(invalid_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Invalid opt-out link')
      end
    end
  end

  describe 'POST /opt-out/:token/hide-directory' do
    context 'with valid token' do
      it 'hides resident from directory' do
        expect(resident.hidden).to be_falsey

        post hide_from_directory_path(token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Success!')
        expect(response.body).to include('Hidden from Directory')

        resident.reload
        expect(resident.hidden).to be_truthy
        expect(resident.email_notifications_opted_out).to be_falsey # Email preference unchanged
      end
    end

    context 'with invalid token' do
      it 'shows error message' do
        post hide_from_directory_path(invalid_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Invalid opt-out link')
      end
    end
  end

  describe 'GET /unsubscribe/:token' do
    context 'with valid token' do
      it 'immediately opts out of emails with quick unsubscribe message' do
        expect(resident.email_notifications_opted_out).to be_falsey

        get one_click_unsubscribe_path(token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Unsubscribed!')
        expect(response.body).to include('You have been unsubscribed from email notifications')
        expect(response.body).to include('You are still listed in the neighborhood directory')

        resident.reload
        expect(resident.email_notifications_opted_out).to be_truthy
        expect(resident.hidden).to be_falsey # Still visible in directory
      end
    end

    context 'with invalid token' do
      it 'shows error message' do
        get one_click_unsubscribe_path(invalid_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Invalid opt-out link')
      end
    end
  end

  describe 'Email opt-out functionality' do
    let(:opted_out_resident) { create(:resident, :opted_out_of_emails) }

    it 'respects email opt-out preference in mailer' do
      # Verify that no email delivery is attempted for opted-out residents
      expect(ResidentMailer).not_to receive(:data_change_notification)

      # Use the class method that handles the conditional logic
      ResidentMailer.deliver_data_change_notification(opted_out_resident, { display_name: { from: 'Old', to: 'New' } })
    end

    it 'sends emails to residents who have not opted out' do
      resident.update!(email_notifications_opted_out: false)

      # Mock deliver_later to verify it IS called for non-opted-out residents
      expect_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later)

      ResidentMailer.deliver_data_change_notification(resident, { display_name: { from: 'Old Name', to: 'New Name' } })
    end

    it 'can create email instance for non-opted-out residents' do
      resident.update!(email_notifications_opted_out: false)

      mail = ResidentMailer.data_change_notification(resident, { display_name: { from: 'Old Name', to: 'New Name' } })

      expect(mail).not_to be_nil
      expect(mail.to).to eq([ resident.email ])
    end
  end

  describe 'Email headers for unsubscribe' do
    it 'includes List-Unsubscribe headers in welcome email' do
      user = create(:user, email: 'user@example.com')

      mail = ResidentMailer.welcome_new_user(resident, user)

      expect(mail['List-Unsubscribe'].to_s).to include('/unsubscribe/')
      expect(mail['List-Unsubscribe-Post'].to_s).to eq('List-Unsubscribe=One-Click')
    end

    it 'includes List-Unsubscribe headers in data change notification' do
      mail = ResidentMailer.data_change_notification(resident, { display_name: { from: 'Old Name', to: 'New Name' } })

      expect(mail['List-Unsubscribe'].to_s).to include('/unsubscribe/')
      expect(mail['List-Unsubscribe-Post'].to_s).to eq('List-Unsubscribe=One-Click')
    end
  end
end
