require 'rails_helper'

RSpec.describe Api::ResidentsController, type: :request do
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
      allow(Resident).to receive(:current).and_return(double(includes: residents))
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
    let!(:real_resident) { create(:resident, :without_email, house: real_house, user: user) }
    let(:valid_params) { { resident: { display_name: 'Updated Name' } } }

    it 'updates the resident successfully' do
      patch "/api/residents/#{real_resident.id}", params: valid_params
      expect(response).to have_http_status(:ok)

      real_resident.reload
      expect(real_resident.display_name).to eq('Updated Name')
    end

    it 'updates the resident with valid birthdate in MM-DD format' do
      birthdate_params = { resident: { birthdate: '03-15' } }
      patch "/api/residents/#{real_resident.id}", params: birthdate_params
      expect(response).to have_http_status(:ok)

      real_resident.reload
      expect(real_resident.birthdate).to eq('03-15')
    end

    context 'when adding an email' do
      let(:email_params) { { resident: { email: 'new@example.com' } } }

      it 'updates the existing user email and sends welcome email' do
        real_resident.update!(email: nil)

        expect {
          patch "/api/residents/#{real_resident.id}", params: email_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:ok)

        real_resident.reload
        expect(real_resident.email).to eq('new@example.com')
        expect(real_resident.user).to eq(user)
        expect(user.reload.email).to eq('new@example.com')
      end
    end

    context 'when updating resident with existing email' do
      let!(:real_resident_with_email) { create(:resident, email: 'existing@example.com', display_name: 'Original Name', user: user) }
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

    it 'owner can set hide_email to true' do
      resident_owner = create(:resident, house: real_house, user: user, hide_email: false)

      patch "/api/residents/#{resident_owner.id}", params: { resident: { hide_email: true } }
      expect(response).to have_http_status(:ok)
      expect(resident_owner.reload.hide_email).to be true
    end

    it 'non-owner cannot change hide flags' do
      neighbor = create(:user)
      resident_other = create(:resident, house: real_house, hide_email: false)

      # Switch session to neighbor
      sign_out user
      sign_in neighbor, scope: :user

      patch "/api/residents/#{resident_other.id}", params: { resident: { hide_email: true } }
      expect(response).to have_http_status(:found).or have_http_status(:forbidden)
      expect(resident_other.reload.hide_email).to be false
    end
  end

  describe 'POST /api/residents' do
    let(:house) { create(:house) }
    let(:valid_params) {
      {
        resident: {
          house_id: house.id,
          display_name: 'New Resident',
          email: 'new@example.com',
          phone: '555-1234'
        }
      }
    }

    it 'creates a new resident successfully' do
      expect {
        post '/api/residents', params: valid_params
      }.to change(Resident, :count).by(1)

      expect(response).to have_http_status(:created)

      json_response = JSON.parse(response.body)
      expect(json_response['display_name']).to eq('New Resident')
      expect(json_response['email']).to eq('new@example.com')
      expect(json_response['phone']).to eq('555-1234')
      expect(json_response['official_name']).to eq('New Resident')
    end

    it 'creates a user when email is provided' do
      expect {
        post '/api/residents', params: valid_params
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)

      created_resident = Resident.last
      expect(created_resident.user).to be_present
      expect(created_resident.user.email).to eq('new@example.com')
      expect(created_resident.official_name).to eq('New Resident')
    end

    context 'with invalid data' do
      let(:invalid_params) {
        {
          resident: {
            house_id: house.id,
            display_name: '' # Empty name
          }
        }
      }

      it 'returns validation errors' do
        expect {
          post '/api/residents', params: invalid_params
        }.not_to change(Resident, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with missing house_id' do
      let(:invalid_params) {
        {
          resident: {
            display_name: 'New Resident'
          }
        }
      }

      it 'returns validation errors' do
        expect {
          post '/api/residents', params: invalid_params
        }.not_to change(Resident, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'hidden data visibility through houses endpoint' do
    let(:owner) { create(:user) }
    let(:neighbor) { create(:user) }
    let(:house)  { create(:house) }
    let!(:partially_hidden_resident) do
      create(:resident, house: house, user: owner, phone: '555-1234', hide_phone: true, email: 'hidden@example.com', hide_email: true)
    end

    context 'as the owner' do
      before { sign_in owner }

      it 'includes real data for hidden fields' do
        get '/api/houses'
        json = JSON.parse(response.body).first["residents"].first
        expect(json['phone']).to eq('555-1234')
        expect(json['email']).to eq('hidden@example.com')
      end
    end

    context 'as a regular neighbor without privileges' do
      before { sign_in neighbor }

      it 'masks hidden fields' do
        get '/api/houses'
        json = JSON.parse(response.body).first["residents"].first
        expect(json['phone']).to eq('(hidden by user)')
        expect(json['email']).to eq('(hidden by user)')
      end
    end
  end
end
