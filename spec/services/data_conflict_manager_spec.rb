require 'rails_helper'

RSpec.describe DataConflictManager, type: :service do
  let(:manager) { described_class.new }
  let(:house) { create(:house) }

  describe '#detect_and_resolve_house_conflicts' do
    context 'when address changes' do
      before do
        house.street_number = 123
        house.street_name = 'Old St'
        house.city = 'Old City'
        house.zip = '12345'
        house.save!
        
        house.street_number = 456
        house.street_name = 'New St'
        house.city = 'New City' 
        house.zip = '67890'
      end

      it 'detects address conflicts' do
        conflicts = manager.detect_and_resolve_house_conflicts(house, {})
        
        expect(conflicts).not_to be_empty
        expect(conflicts.first[:type]).to eq('address_change')
        expect(conflicts.first[:old_address]).to include('Old St')
        expect(conflicts.first[:new_address]).to include('New St')
      end
    end

    context 'when coordinates change significantly' do
      before do
        house.latitude = 27.7676
        house.longitude = -82.6403
        house.save!
        
        house.latitude = 27.7700  # ~267m north
        house.longitude = -82.6403
      end

      it 'detects significant coordinate changes' do
        conflicts = manager.detect_and_resolve_house_conflicts(house, {})
        
        expect(conflicts).not_to be_empty
        expect(conflicts.first[:type]).to eq('coordinate_change')
        expect(conflicts.first[:distance_moved]).to be > 10 # meters
      end
    end
  end

  describe '#detect_ownership_conflicts' do
    let!(:current_resident) { create(:resident, house: house, official_name: 'John Doe', last_seen_at: nil) }

    context 'when ownership changes' do
      it 'detects ownership conflicts' do
        conflicts = manager.detect_ownership_conflicts(house, 'Jane Smith', nil)
        
        expect(conflicts).not_to be_empty
        expect(conflicts.first[:type]).to eq('ownership_change')
        expect(conflicts.first[:old_owners]).to include('John Doe')
        expect(conflicts.first[:new_owners]).to include('Jane Smith')
      end
    end

    context 'when ownership stays the same' do
      it 'does not detect conflicts' do
        conflicts = manager.detect_ownership_conflicts(house, 'John Doe', nil)
        
        expect(conflicts).to be_empty
      end
    end
  end

  describe '#summary' do
    before do
      house.street_number = 123
      house.street_name = 'Test St'
      house.save!
      house.street_number = 456
      
      manager.detect_and_resolve_house_conflicts(house, {})
    end

    it 'provides conflict summary' do
      summary = manager.summary
      
      expect(summary[:total_conflicts]).to eq(1)
      expect(summary[:resolved_automatically]).to eq(1)
      expect(summary[:conflicts_by_type]).to have_key('address_change')
    end
  end
end