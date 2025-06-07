# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Resident homepage normalization', type: :request do
  describe 'PATCH /api/residents/:id' do
    let!(:house) { create(:house) }
    let!(:resident) { create(:resident, house: house, display_name: 'Old Name') }

    it 'normalizes homepage without protocol and persists successfully' do
      params = {
        resident: {
          display_name: 'Chuck',
          homepage: 'example.com'
        }
      }

      patch "/api/residents/#{resident.id}", params: params, as: :json

      expect(response).to have_http_status(:ok)

      resident.reload
      expect(resident.homepage).to eq('https://example.com')
      expect(resident.display_name).to eq('Chuck')
    end
  end
end