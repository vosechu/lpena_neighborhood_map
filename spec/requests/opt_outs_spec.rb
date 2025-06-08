require 'rails_helper'

RSpec.describe OptOutsController, type: :request do
  let(:resident) { create(:resident, email: 'test@example.com', hidden: false) }
  let(:token_data) { { resident_id: resident.id, expires_at: 30.days.from_now.to_s } }
  let(:valid_token) { Rails.application.message_verifier(:opt_out).generate(token_data) }
  let(:expired_token_data) { { resident_id: resident.id, expires_at: 1.day.ago.to_s } }
  let(:expired_token) { Rails.application.message_verifier(:opt_out).generate(expired_token_data) }
  let(:invalid_token) { 'invalid-token' }

  describe 'GET /opt-out/:token' do
    context 'with valid token' do
      it 'shows the opt-out page' do
        get opt_out_path(valid_token)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Remove from Neighborhood Directory')
        expect(response.body).to include(resident.display_name.presence || resident.official_name)
      end
    end

    context 'with expired token' do
      it 'shows error message' do
        get opt_out_path(expired_token)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('This opt-out link has expired')
        expect(response.body).to include('vosechu@gmail.com')
      end
    end

    context 'with invalid token' do
      it 'shows error message' do
        get opt_out_path(invalid_token)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Invalid opt-out link')
        expect(response.body).to include('vosechu@gmail.com')
      end
    end

    context 'with token for non-existent resident' do
      let(:invalid_resident_token) { Rails.application.message_verifier(:opt_out).generate({ resident_id: 99999, expires_at: 30.days.from_now.to_s }) }

      it 'shows error message' do
        get opt_out_path(invalid_resident_token)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Resident not found')
        expect(response.body).to include('vosechu@gmail.com')
      end
    end
  end

  describe 'POST /opt-out/:token' do
    context 'with valid token' do
      it 'opts out the resident and shows success message' do
        expect {
          post opt_out_path(valid_token)
        }.to change { resident.reload.hidden }.from(false).to(true)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Success!')
        expect(response.body).to include('You have been removed from the neighborhood directory')
      end
    end

    context 'with expired token' do
      it 'shows error message and does not opt out' do
        expect {
          post opt_out_path(expired_token)
        }.not_to change { resident.reload.hidden }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('This opt-out link has expired')
      end
    end

    context 'with invalid token' do
      it 'shows error message and does not opt out' do
        expect {
          post opt_out_path(invalid_token)
        }.not_to change { resident.reload.hidden }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Invalid opt-out link')
      end
    end

    context 'when update fails' do
      it 'shows error message' do
        allow_any_instance_of(Resident).to receive(:update).and_return(false)

        post opt_out_path(valid_token)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Unable to process opt-out request')
      end
    end
  end
end
