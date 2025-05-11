require 'rails_helper'

RSpec.describe 'Api::ResidentsController', type: :request do
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
