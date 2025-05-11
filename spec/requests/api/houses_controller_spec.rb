require 'rails_helper'

RSpec.describe 'Api::HousesController', type: :request do
  describe 'GET /api/houses' do
    let(:houses) { [ instance_double(House), instance_double(House) ] }
    let(:serialized_houses) { [ { id: 1, name: 'House 1' }, { id: 2, name: 'House 2' } ] }

    before do
      allow(House).to receive_message_chain(:includes, :all).and_return(houses)
      houses.each_with_index do |house, i|
        serializer = instance_double(HouseSerializer)
        allow(HouseSerializer).to receive(:new).with(house).and_return(serializer)
        allow(serializer).to receive(:as_json).and_return(serialized_houses[i])
      end
    end

    it 'returns a successful response' do
      get '/api/houses'
      expect(response).to have_http_status(:ok)
    end

    it 'returns the expected JSON structure' do
      get '/api/houses'
      expect(JSON.parse(response.body)).to eq(serialized_houses.as_json)
    end
  end
end
