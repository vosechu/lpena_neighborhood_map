require 'rails_helper'

RSpec.describe 'Api::HousesController', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe 'GET /api/houses' do
    let!(:house1) { create(:house) }
    let!(:house2) { create(:house) }

    it 'returns a successful response' do
      get '/api/houses'
      expect(response).to have_http_status(:ok)
    end

    it 'returns houses in JSON format' do
      get '/api/houses'
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.length).to eq(2)
    end
  end
end
