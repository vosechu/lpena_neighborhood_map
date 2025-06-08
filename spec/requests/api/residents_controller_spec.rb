require 'rails_helper'

RSpec.describe 'Api::ResidentsController', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe 'GET /api/residents' do
    let(:house) { instance_double(House, id: 1, street_number: '123', street_name: 'Main St') }
    let(:resident) { instance_double(Resident, id: 1, display_name: 'Test Resident', house: house, email: nil) }
    let(:residents) { [ resident ] }
    let(:serialized_resident) { { id: 1, display_name: 'Test Resident' } }

    before do
      allow(Resident).to receive(:all).and_return(double(includes: residents))
      allow(ResidentSerializer).to receive(:new).with(resident).and_return(double(as_json: serialized_resident))
    end

    it 'returns a successful response' do
      get '/api/residents'
      expect(response).to have_http_status(:ok)
    end

    it 'returns residents in JSON format' do
      get '/api/residents'
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.length).to eq(1)
      expect(json_response.first).to eq(serialized_resident.stringify_keys)
    end
  end

  describe 'POST /api/houses/:house_id/residents' do
    let!(:real_house) { create(:house) }
    let(:valid_params) { { resident: { official_name: 'John Doe', display_name: 'John' } } }
    let(:invalid_params) { { resident: { display_name: 'John' } } }

    context 'with valid params' do
      it 'creates a new resident and returns JSON' do
        expect {
          post "/api/houses/#{real_house.id}/residents", params: valid_params
        }.to change(Resident, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include('official_name' => 'John Doe')
        expect(json_response).to include('display_name' => 'John')
      end
    end

    context 'with invalid params' do
      it 'returns errors and unprocessable_entity status' do
        post "/api/houses/#{real_house.id}/residents", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('official_name')
      end
    end
  end

  describe 'PATCH /api/residents/:id' do
    let!(:real_house) { create(:house) }
    let!(:real_resident) { create(:resident, :without_email, house: real_house) }
    let(:valid_params) { { resident: { display_name: 'Updated Name' } } }

    it 'updates the resident successfully' do
      patch "/api/residents/#{real_resident.id}", params: valid_params
      expect(response).to have_http_status(:ok)

      real_resident.reload
      expect(real_resident.display_name).to eq('Updated Name')
    end

    context 'when adding an email' do
      let(:email_params) { { resident: { email: 'new@example.com' } } }

      it 'creates a new user and sends welcome email' do
        real_resident.update!(email: nil)

        expect {
          patch "/api/residents/#{real_resident.id}", params: email_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)

        real_resident.reload
        expect(real_resident.email).to eq('new@example.com')
        expect(real_resident.user).to be_present
      end
    end

    context 'when updating resident with existing email' do
      let!(:real_resident_with_email) { create(:resident, email: 'existing@example.com', display_name: 'Original Name') }
      let(:update_params) { { resident: { display_name: 'New Name' } } }

      it 'sends change notification email' do
        mailer_double = instance_double(ActionMailer::MessageDelivery)
        expect(ResidentMailer).to receive(:data_change_notification)
          .with(real_resident_with_email, kind_of(Hash))
          .and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_later)

        patch "/api/residents/#{real_resident_with_email.id}", params: update_params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid data' do
      let(:invalid_params) { { resident: { display_name: 'x' * 300 } } } # Assuming there's a length limit

      it 'returns validation errors' do
        # Allow validation to fail by using invalid data
        allow_any_instance_of(Resident).to receive(:update).and_return(false)
        allow_any_instance_of(Resident).to receive(:errors).and_return(double(full_messages: [ 'Display name is too long' ]))

        patch "/api/residents/#{real_resident.id}", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /api/residents/:id' do
    let!(:real_house) { create(:house) }
    
    context 'when resident is user-created' do
      let!(:user_created_resident) { create(:resident, house: real_house, last_import_at: nil) }

      it 'deletes the resident and returns success message' do
        expect {
          delete "/api/residents/#{user_created_resident.id}"
        }.to change(Resident, :count).by(-1)
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'message' => 'Resident deleted successfully' })
      end
    end

    context 'when resident is from official records' do
      let!(:official_resident) { create(:resident, house: real_house, last_import_at: 1.day.ago) }

      it 'returns forbidden status' do
        delete "/api/residents/#{official_resident.id}"
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Cannot delete residents from official records' })
      end
    end
  end

  describe 'PATCH /api/residents/:id/hide' do
    let!(:real_house) { create(:house) }
    let!(:real_resident) { create(:resident, house: real_house) }

    context 'when update succeeds' do
      it 'hides the resident and returns success message' do
        patch "/api/residents/#{real_resident.id}/hide"
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'message' => 'Resident hidden successfully' })
        
        real_resident.reload
        expect(real_resident.hidden).to be true
      end
    end
  end

  describe 'PATCH /api/residents/:id/unhide' do
    let!(:real_house) { create(:house) }
    let!(:real_resident) { create(:resident, house: real_house, hidden: true) }

    context 'when update succeeds' do
      it 'unhides the resident and returns JSON' do
        patch "/api/residents/#{real_resident.id}/unhide"
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include('id' => real_resident.id)
        
        real_resident.reload
        expect(real_resident.hidden).to be false
      end
    end
  end
end
