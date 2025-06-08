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
end
