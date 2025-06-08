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
      it 'updates the resident and returns JSON' do
        patch "/api/residents/#{resident.id}", params: valid_params
        expect(response).to have_http_status(:ok)
        
        resident.reload
        expect(resident.display_name).to eq('Updated Name')
      end
    end

    context 'with invalid params' do
      it 'returns errors and unprocessable_entity status' do
        patch "/api/residents/#{resident.id}", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('email')
      end
    end
  end
end
