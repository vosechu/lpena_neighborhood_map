require 'rails_helper'

RSpec.describe 'Api::ResidentsController', type: :request do
  describe 'GET /api/residents' do
    let!(:house1) { create(:house) }
    let!(:house2) { create(:house) }
    let!(:resident1) { create(:resident, house: house1, official_name: 'John Doe', first_seen_at: 15.days.ago) }
    let!(:resident2) { create(:resident, house: house2, official_name: 'Jane Smith', first_seen_at: 45.days.ago) }

    context 'without filters' do
      it 'returns all visible residents' do
        get '/api/residents'
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(2)
      end
    end

    context 'with name search' do
      it 'filters residents by name' do
        get '/api/residents', params: { search: 'John' }
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(1)
        expect(json_response.first['official_name']).to eq('John Doe')
      end
    end

    context 'with subscription filter' do
      it 'filters subscribed residents' do
        # Assuming resident1 has ID 1 (odd) and is subscribed
        get '/api/residents', params: { subscribed: 'true' }
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        subscribed_residents = json_response.select { |r| r['subscribed'] == true }
        expect(subscribed_residents.length).to be > 0
      end
    end

    context 'with new residents filter' do
      it 'filters new residents' do
        get '/api/residents', params: { new_residents: 'true' }
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(1)
        expect(json_response.first['official_name']).to eq('John Doe')
      end
    end
  end

  describe 'PATCH /api/residents/:id' do
    let(:resident) { instance_double(Resident, id: 1, as_json: { id: 1, display_name: 'Test' }) }
    let(:valid_params) { { resident: { display_name: 'Test' } } }
    let(:invalid_params) { { resident: { display_name: '' } } }
    let(:errors) { { display_name: [ "can't be blank" ] } }

    before do
      allow(Resident).to receive(:find).with(resident.id.to_s).and_return(resident)
    end

    context 'with valid params' do
      before do
        allow(resident).to receive(:update).and_return(true)
      end

      it 'updates the resident and returns JSON' do
        patch "/api/residents/#{resident.id}", params: valid_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(resident.as_json.as_json)
      end
    end

    context 'with invalid params' do
      before do
        allow(resident).to receive(:update).and_return(false)
        allow(resident).to receive(:errors).and_return(errors)
      end

      it 'returns errors and unprocessable_entity status' do
        patch "/api/residents/#{resident.id}", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(errors.as_json)
      end
    end
  end
end
