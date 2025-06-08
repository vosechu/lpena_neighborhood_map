require 'rails_helper'

RSpec.describe Resident do
  describe 'validations' do
    let(:resident) { build(:resident, :minimal) }

    it 'requires a house' do
      resident.house = nil
      expect(resident).not_to be_valid
      expect(resident.errors[:house]).to include("can't be blank")
    end

    it 'requires an official_name' do
      resident.official_name = nil
      expect(resident).not_to be_valid
      expect(resident.errors[:official_name]).to include("can't be blank")
    end

    it 'requires first_seen_at' do
      resident.first_seen_at = nil
      expect(resident).not_to be_valid
      expect(resident.errors[:first_seen_at]).to include("can't be blank")
    end
  end

  describe 'associations' do
    let(:resident) { create(:resident) }

    it 'belongs to a house' do
      expect(resident.house).to be_present
    end

    it 'can belong to a user' do
      user = create(:user)
      resident.user = user
      expect(resident.user).to eq(user)
    end
  end

  describe 'privacy settings' do
    let(:resident) { build(:resident) }

    it 'defaults to private visibility' do
      expect(resident.public_visibility).to be false
    end

    it 'can be made publicly visible' do
      resident.public_visibility = true
      expect(resident).to be_valid
      expect(resident.public_visibility).to be true
    end
  end

  describe 'a valid resident' do
    let(:resident) { build(:resident) }

    it 'is valid with factory defaults' do
      expect(resident).to be_valid
    end

    it 'includes all required fields' do
      expect(resident.house).to be_present
      expect(resident.official_name).to be_present
      expect(resident.first_seen_at).to be_present
    end
  end

  describe '#subscribed?' do
    it 'returns true for odd IDs' do
      resident = build(:resident, id: 1)
      expect(resident.subscribed?).to be true
    end

    it 'returns false for even IDs' do
      resident = build(:resident, id: 2)
      expect(resident.subscribed?).to be false
    end
  end

  describe '.subscribed scope' do
    before do
      create(:resident, id: 1) # Should be subscribed
      create(:resident, id: 2) # Should not be subscribed
      create(:resident, id: 3) # Should be subscribed
    end

    it 'returns only subscribed residents' do
      subscribed_ids = Resident.subscribed.pluck(:id)
      expect(subscribed_ids).to contain_exactly(1, 3)
    end
  end

  describe '.new_residents scope' do
    before do
      create(:resident, first_seen_at: 15.days.ago)
      create(:resident, first_seen_at: 45.days.ago)
    end

    it 'returns residents from the last 30 days' do
      expect(Resident.new_residents.count).to eq(1)
    end
  end
end
