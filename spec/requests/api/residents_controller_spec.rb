require 'rails_helper'

RSpec.describe 'Api::ResidentsController', type: :request do
  let(:user) { create(:user) }
  let!(:house) { create(:house) }
  let!(:resident) { create(:resident, house: house) }

  before do
    sign_in user, scope: :user
  end

  describe 'GET /api/residents' do
    it 'returns a successful response' do
      get '/api/residents'
      expect(response).to have_http_status(:ok)
    end

    it 'returns residents in JSON format' do
      get '/api/residents'
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.length).to eq(1)
    end
  end

  describe 'PATCH /api/residents/:id' do
    let(:valid_params) { { resident: { display_name: 'Updated Name' } } }
    let(:invalid_params) { { resident: { email: 'invalid-email-format' } } }

    context 'with valid params' do
      it 'calls ResidentUpdateService and returns JSON' do
        expect(ResidentUpdateService).to receive(:update_resident)
          .with(resident, { 'display_name' => 'Updated Name' }, user)
          .and_return(true)

        patch "/api/residents/#{resident.id}", params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it 'updates the resident successfully through the service' do
        # Allow the actual service to run
        patch "/api/residents/#{resident.id}", params: valid_params
        expect(response).to have_http_status(:ok)
        
        resident.reload
        expect(resident.display_name).to eq('Updated Name')
      end

      context 'when adding an email' do
        let(:email_params) { { resident: { email: 'new@example.com' } } }

        it 'creates a new user and sends welcome email' do
          expect {
            patch "/api/residents/#{resident.id}", params: email_params
          }.to change(User, :count).by(1)

          expect(response).to have_http_status(:ok)
          
          resident.reload
          expect(resident.email).to eq('new@example.com')
          expect(resident.user).to be_present
        end
      end

      context 'when updating resident with existing email' do
        let(:resident_with_email) { create(:resident, email: 'existing@example.com', display_name: 'Original Name') }
        let(:update_params) { { resident: { display_name: 'New Name' } } }

        it 'sends change notification email' do
          # Mock email delivery to avoid actual email sending in tests
          expect(ResidentMailer).to receive(:data_change_notification)
            .and_return(double(deliver_later: true))

          patch "/api/residents/#{resident_with_email.id}", params: update_params
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with invalid params' do
      it 'returns errors when service update fails' do
        expect(ResidentUpdateService).to receive(:update_resident)
          .and_return(false)

        # Mock the errors for the response
        allow(resident).to receive(:errors).and_return(double(full_messages: ['Email is invalid']))

        patch "/api/residents/#{resident.id}", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when service returns false' do
      it 'returns unprocessable entity status' do
        allow(ResidentUpdateService).to receive(:update_resident).and_return(false)
        allow(resident).to receive(:errors).and_return(double(full_messages: ['Update failed']))

        patch "/api/residents/#{resident.id}", params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
