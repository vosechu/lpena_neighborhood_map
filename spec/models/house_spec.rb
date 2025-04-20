require 'rails_helper'

RSpec.describe House do
  describe 'validations' do
    let(:house) { build(:house, :minimal) }  # Use minimal trait for validation tests

    %i[pcpa_uid street_number street_name city state zip latitude longitude boundary_geometry].each do |field|
      it "requires #{field}" do
        house.assign_attributes(valid_attributes.except(field))
        expect(house).not_to be_valid
        expect(house.errors[field]).to include("can't be blank")
      end
    end

    it 'requires a unique pcpa_uid' do
      create(:house, pcpa_uid: '123456')
      duplicate = build(:house, pcpa_uid: '123456')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:pcpa_uid]).to include('has already been taken')
    end
  end

  describe 'associations' do
    let(:house) { create(:house) }

    it 'can have many residents' do
      resident = create(:resident, house: house)
      expect(house.residents.reload).to eq([resident])
    end

    it 'can access users through residents' do
      user = create(:user)
      create(:resident, house: house, user: user)
      expect(house.users).to include(user)
    end
  end

  describe 'a valid house' do
    let(:house) { build(:house) }

    it 'is valid with factory defaults' do
      expect(house).to be_valid
    end

    it 'includes all required location data' do
      expect(house.latitude).to be_present
      expect(house.longitude).to be_present
      expect(house.boundary_geometry).to be_present
    end

    it 'includes all required address data' do
      expect(house.street_number).to be_present
      expect(house.street_name).to be_present
      expect(house.city).to be_present
      expect(house.state).to be_present
      expect(house.zip).to be_present
    end
  end

  private

  def valid_attributes
    attributes_for(:house)
  end
end
