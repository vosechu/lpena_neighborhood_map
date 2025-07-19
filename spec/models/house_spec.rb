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
      expect(house.residents.reload).to eq([ resident ])
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

  describe '#to_s' do
    let(:house) { build(:house, street_number: '123', street_name: 'Main St') }

    it 'returns formatted address' do
      expect(house.to_s).to eq('123 Main St')
    end
  end

  describe '#ransackable_attributes' do
    it 'returns the expected attributes' do
      expect(described_class.ransackable_attributes).to eq(['city', 'id', 'street_name', 'street_number', 'zip'])
    end
  end

  describe '#ransackable_associations' do
    it 'returns the expected associations' do
      expect(described_class.ransackable_associations).to eq(['residents', 'users'])
    end
  end

  describe '#events' do
    let(:house) { create(:house) }

    context 'when there are no events' do
      it 'returns an empty array' do
        expect(house.events).to eq([])
      end
    end

    context 'when there are birthday events' do
      let!(:resident_with_birthday) do
        create(:resident, house: house, birthdate: (Date.current + 5.days).strftime('%m-%d'), hide_birthdate: false, display_name: 'Alice', first_seen_at: 2.months.ago)
      end
      let!(:resident_without_birthday) do
        create(:resident, house: house, birthdate: (Date.current - 40.days).strftime('%m-%d'), display_name: 'Bob', first_seen_at: 2.months.ago)
      end

      it 'returns birthday events' do
        events = house.events
        expect(events.length).to eq(1)
        expect(events.first[:type]).to eq('birthday')
        expect(events.first[:icon]).to eq('🎂')
        expect(events.first[:message]).to include("Alice has an upcoming birthday on #{resident_with_birthday.formatted_birthdate}!")
      end
    end

    context 'when there are new resident events' do
      let!(:new_resident) do
        create(:resident, house: house, first_seen_at: 15.days.ago)
      end

      it 'returns new resident events' do
        events = house.events
        expect(events.length).to eq(1)
        expect(events.first[:type]).to eq('new_residents')
        expect(events.first[:icon]).to eq('🎁')
        expect(events.first[:message]).to include('recently moved in!')
      end
    end

    context 'when there are both birthday and new resident events' do
      let!(:resident_with_birthday) do
        create(:resident, house: house, birthdate: '12-25', hide_birthdate: false)
      end
      let!(:new_resident) do
        create(:resident, house: house, first_seen_at: 15.days.ago)
      end

      before do
        # Mock the birthday_upcoming? method to return true for our test
        allow_any_instance_of(Resident).to receive(:birthday_upcoming?).and_return(true)
        allow_any_instance_of(Resident).to receive(:formatted_birthdate).and_return('December 25')
      end

      it 'returns both events' do
        events = house.events
        expect(events.length).to eq(2)
        expect(events.map { |e| e[:type] }).to contain_exactly('birthday', 'new_residents')
      end
    end
  end

  describe '#icon_type' do
    let(:house) { create(:house) }

    context 'when there are no events' do
      it 'returns nil' do
        expect(house.icon_type).to be_nil
      end
    end

    context 'when there is one event' do
      before do
        allow(house).to receive(:events).and_return([{ type: 'birthday' }])
      end

      it 'returns the event type' do
        expect(house.icon_type).to eq('birthday')
      end
    end

    context 'when there are multiple events' do
      before do
        allow(house).to receive(:events).and_return([
          { type: 'birthday' },
          { type: 'new_residents' }
        ])
      end

      it 'returns star' do
        expect(house.icon_type).to eq('star')
      end
    end
  end

  describe '#birthday_events' do
    let(:house) { create(:house) }
    let!(:resident_with_birthday) do
      create(:resident, house: house, birthdate: '12-25', hide_birthdate: false)
    end
    let!(:resident_without_birthday) do
      create(:resident, house: house, birthdate: nil)
    end

    context 'when there are residents with upcoming birthdays' do
      before do
        # Mock the birthday_upcoming? method to return true for our test
        allow_any_instance_of(Resident).to receive(:birthday_upcoming?).and_return(true)
        allow_any_instance_of(Resident).to receive(:formatted_birthdate).and_return('December 25')
      end

      it 'returns birthday event' do
        events = house.send(:birthday_events)
        expect(events.length).to eq(1)
        expect(events.first[:type]).to eq('birthday')
        expect(events.first[:icon]).to eq('🎂')
        expect(events.first[:message]).to include('has an upcoming birthday on December 25!')
      end
    end

    context 'when there are no residents with upcoming birthdays' do
      before do
        # Mock the birthday_upcoming? method to return false for our test
        allow_any_instance_of(Resident).to receive(:birthday_upcoming?).and_return(false)
      end

      it 'returns empty array' do
        expect(house.send(:birthday_events)).to eq([])
      end
    end

    context 'when there are multiple residents with upcoming birthdays' do
      let!(:resident1) do
        create(:resident, house: house, birthdate: (Date.current + 5.days).strftime('%m-%d'), hide_birthdate: false, display_name: 'Alice', first_seen_at: 2.months.ago)
      end
      let!(:resident2) do
        create(:resident, house: house, birthdate: (Date.current + 10.days).strftime('%m-%d'), hide_birthdate: false, display_name: 'Bob', first_seen_at: 2.months.ago)
      end
      let!(:resident3) do
        create(:resident, house: house, birthdate: (Date.current - 40.days).strftime('%m-%d'), display_name: 'Charlie', first_seen_at: 2.months.ago)
      end

      it 'includes both residents in the message' do
        events = house.send(:birthday_events)
        expect(events.length).to eq(1)
        expect(events.first[:message]).to include("Alice has an upcoming birthday on #{resident1.formatted_birthdate}!")
        expect(events.first[:message]).to include("Bob has an upcoming birthday on #{resident2.formatted_birthdate}!")
        expect(events.first[:message]).to include('<br />')
      end
    end
  end

  describe '#new_resident_events' do
    let(:house) { create(:house) }

    context 'when there are recently moved in residents' do
      let!(:new_resident) do
        create(:resident, house: house, first_seen_at: 15.days.ago)
      end

      it 'returns new resident event' do
        events = house.send(:new_resident_events)
        expect(events.length).to eq(1)
        expect(events.first[:type]).to eq('new_residents')
        expect(events.first[:icon]).to eq('🎁')
        expect(events.first[:message]).to include('recently moved in!')
      end
    end

    context 'when there are no recently moved in residents' do
      let!(:old_resident) do
        create(:resident, house: house, first_seen_at: 60.days.ago)
      end

      it 'returns empty array' do
        expect(house.send(:new_resident_events)).to eq([])
      end
    end

    context 'when there are multiple recently moved in residents' do
      let!(:first_new_resident) do
        create(:resident, house: house, first_seen_at: 15.days.ago, display_name: 'Alice')
      end
      let!(:second_new_resident) do
        create(:resident, house: house, first_seen_at: 20.days.ago, display_name: 'Bob')
      end

      it 'includes both residents in the message' do
        events = house.send(:new_resident_events)
        expect(events.length).to eq(1)
        expect(events.first[:message]).to include('Alice and Bob recently moved in!')
      end
    end
  end

  describe '#birthday_message' do
    let(:house) { create(:house) }
    let(:resident1) { instance_double(Resident, to_s: 'Alice', formatted_birthdate: 'December 25') }
    let(:resident2) { instance_double(Resident, to_s: 'Bob', formatted_birthdate: 'January 15') }

    it 'formats single resident message' do
      message = house.send(:birthday_message, [resident1])
      expect(message).to eq('Alice has an upcoming birthday on December 25!')
    end

    it 'formats multiple residents message' do
      message = house.send(:birthday_message, [resident1, resident2])
      expect(message).to eq('Alice has an upcoming birthday on December 25!<br />Bob has an upcoming birthday on January 15!')
    end
  end

  describe '#new_residents_message' do
    let(:house) { create(:house) }
    let(:resident1) { instance_double(Resident, to_s: 'Alice') }
    let(:resident2) { instance_double(Resident, to_s: 'Bob') }

    it 'formats single resident message' do
      message = house.send(:new_residents_message, [resident1])
      expect(message).to eq('Alice recently moved in!')
    end

    it 'formats multiple residents message' do
      message = house.send(:new_residents_message, [resident1, resident2])
      expect(message).to eq('Alice and Bob recently moved in!')
    end
  end

  private

  def valid_attributes
    attributes_for(:house)
  end
end
