require 'rails_helper'

RSpec.describe HouseImportService do
  describe '.call' do
    let(:house_details) do
      {
        'attributes' => {
          'PCPA_UID' => 'test-uid-123',
          'STR_NUM' => 6573,
          'SITE_ADDR' => '6573 1st Ave N',
          'SITE_CITY' => 'St Petersburg',
          'SITE_CITYZIP' => 'St Petersburg, FL 33710',
          'LATITUDE' => 27.772074174,
          'LONGITUDE' => -82.728144652
        },
        'geometry' => {
          'rings' => [
            [
              [ -9209240.7571388613, 3220294.4717873628 ],
              [ -9209240.5707909688, 3220242.5645591398 ],
              [ -9209269.8302294277, 3220242.4562229472 ],
              [ -9209270.0166863501, 3220294.3632209231 ],
              [ -9209240.7571388613, 3220294.4717873628 ]
            ]
          ]
        }
      }
    end

    it 'does not change the house if everything is the same except the pcpa_uid' do
      # Create an existing house with the same address but different pcpa_uid
      existing_house = FactoryBot.create(:house,
        street_number: 6573,
        street_name: '1st Ave N',
        city: 'St Petersburg',
        state: 'FL',
        zip: '33710',
        latitude: 27.772074174,
        longitude: -82.728144652,
        boundary_geometry: {
          'rings' => [
            [
              [ -9209240.7571388613, 3220294.4717873628 ],
              [ -9209240.5707909688, 3220242.5645591398 ],
              [ -9209269.8302294277, 3220242.4562229472 ],
              [ -9209270.0166863501, 3220294.3632209231 ],
              [ -9209240.7571388613, 3220294.4717873628 ]
            ]
          ]
        }
      )

      # Change the pcpa_uid in the incoming data
      house_details['attributes']['PCPA_UID'] = 'different-uid-456'

      expect {
        result = described_class.call(house_details)
        expect(result).to eq(existing_house)
      }.not_to change { existing_house.reload.updated_at }

      # Verify the house wasn't updated
      existing_house.reload
      expect(existing_house.street_number).to eq(6573)
      expect(existing_house.street_name).to eq('1st Ave N')
      expect(existing_house.city).to eq('St Petersburg')
      expect(existing_house.state).to eq('FL')
      expect(existing_house.zip).to eq('33710')
      expect(existing_house.latitude).to be_within(0.000001).of(27.772074174)
      expect(existing_house.longitude).to be_within(0.000001).of(-82.728144652)
      expect(existing_house.boundary_geometry).to eq(house_details['geometry'])
    end

    it 'creates a new house when one does not exist' do
      expect {
        result = described_class.call(house_details)
        expect(result).to be_persisted
        expect(result.street_number).to eq(6573)
        expect(result.street_name).to eq('1st Ave N')
        expect(result.city).to eq('St Petersburg')
        expect(result.state).to eq('FL')
        expect(result.zip).to eq('33710')
        expect(result.pcpa_uid).to eq('test-uid-123')
      }.to change(House, :count).by(1)
    end

    it 'updates an existing house when attributes change' do
      existing_house = FactoryBot.create(:house,
        street_number: 6573,
        street_name: '1st Ave N',
        city: 'St Petersburg',
        state: 'FL',
        zip: '33710',
        latitude: 27.772074174,
        longitude: -82.728144652
      )

      # Change the latitude
      house_details['attributes']['LATITUDE'] = 28.0

      expect {
        result = described_class.call(house_details)
        expect(result).to eq(existing_house)
      }.to change { existing_house.reload.latitude }.to(28.0)
    end
  end

  describe '#house_attributes' do
    let(:service) { described_class.new(house_details) }
    let(:house_details) do
      {
        'attributes' => {
          'PCPA_UID' => 'test-uid-123',
          'STR_NUM' => 6573,
          'SITE_ADDR' => '6573 1st Ave N',
          'SITE_CITY' => 'St Petersburg',
          'SITE_CITYZIP' => 'St Petersburg, FL 33710',
          'LATITUDE' => 27.772074174,
          'LONGITUDE' => -82.728144652
        },
        'geometry' => { 'rings' => [] }
      }
    end

    it 'extracts all attributes correctly for a new house' do
      house = House.new
      attributes = service.house_attributes(house)

      expect(attributes).to eq({
        pcpa_uid: 'test-uid-123',
        street_number: 6573,
        street_name: '1st Ave N',
        city: 'St Petersburg',
        state: 'FL',
        zip: '33710',
        latitude: 27.772074174,
        longitude: -82.728144652,
        boundary_geometry: { 'rings' => [] }
      })
    end

    it 'does not set pcpa_uid for existing houses' do
      house = FactoryBot.create(:house)
      attributes = service.house_attributes(house)

      expect(attributes[:pcpa_uid]).to be_nil
      expect(attributes[:street_number]).to eq(6573)
      expect(attributes[:street_name]).to eq('1st Ave N')
    end
  end

  describe 'attribute extraction methods' do
    let(:service) { described_class.new(house_details) }
    let(:house_details) do
      {
        'attributes' => {
          'PCPA_UID' => 'test-uid-123',
          'STR_NUM' => 6573,
          'SITE_ADDR' => '6573 1st Ave N',
          'SITE_CITY' => 'St Petersburg',
          'SITE_CITYZIP' => 'St Petersburg, FL 33710',
          'LATITUDE' => 27.772074174,
          'LONGITUDE' => -82.728144652
        },
        'geometry' => { 'rings' => [] }
      }
    end

    describe '#extract_city' do
      it 'extracts city from SITE_CITY with trailing comma' do
        house_details['attributes']['SITE_CITY'] = 'St Petersburg,'

        expect(service.send(:extract_city)).to eq('St Petersburg')
      end

      it 'extracts city from SITE_CITYZIP when SITE_CITY is missing' do
        house_details['attributes']['SITE_CITY'] = nil
        house_details['attributes']['SITE_CITYZIP'] = 'St Petersburg, Fl 33710'

        expect(service.send(:extract_city)).to eq('St Petersburg')
      end

      it 'handles missing SITE_CITYZIP' do
        house_details['attributes']['SITE_CITY'] = nil
        house_details['attributes']['SITE_CITYZIP'] = nil

        expect(service.send(:extract_city)).to be_nil
      end

      it 'handles empty string values' do
        house_details['attributes']['SITE_CITY'] = ''
        house_details['attributes']['SITE_CITYZIP'] = 'St Petersburg, Fl 33710'

        expect(service.send(:extract_city)).to eq('St Petersburg')
      end

      it 'handles whitespace-only values' do
        house_details['attributes']['SITE_CITY'] = '   '
        house_details['attributes']['SITE_CITYZIP'] = 'St Petersburg, Fl 33710'

        expect(service.send(:extract_city)).to eq('St Petersburg')
      end

      it 'handles null CITY field' do
        house_details['attributes']['SITE_CITY'] = nil
        house_details['attributes']['SITE_CITYZIP'] = 'St Petersburg, Fl 33710'

        expect(service.send(:extract_city)).to eq('St Petersburg')
      end
    end

    describe '#extract_zip' do
      it 'extracts zip from SITE_CITYZIP' do
        house_details['attributes']['SITE_CITYZIP'] = 'St Petersburg, Fl 33710'

        expect(service.send(:extract_zip)).to eq('33710')
      end

      it 'handles missing SITE_CITYZIP' do
        house_details['attributes']['SITE_CITYZIP'] = nil

        expect(service.send(:extract_zip)).to be_nil
      end
    end

    describe '#extract_street_name' do
      it 'extracts street name correctly' do
        house_details['attributes']['STR_NUM'] = 213
        house_details['attributes']['SITE_ADDR'] = '213 66th St N'

        expect(service.send(:extract_street_name)).to eq('66th St N')
      end

      it 'handles street name when STR_NUM is nil' do
        house_details['attributes']['STR_NUM'] = nil
        house_details['attributes']['SITE_ADDR'] = 'Some Street Name'

        expect(service.send(:extract_street_name)).to eq('Some Street Name')
      end

      it 'handles pathological case where street name is a number' do
        house_details['attributes']['STR_NUM'] = 1
        house_details['attributes']['SITE_ADDR'] = '1 1st Ave N'

        expect(service.send(:extract_street_name)).to eq('1st Ave N')
      end

      it 'handles addresses with no street number' do
        house_details['attributes']['STR_NUM'] = 0
        house_details['attributes']['SITE_ADDR'] = '1st Ave N'

        expect(service.send(:extract_street_name)).to eq('1st Ave N')
      end

      it 'handles edge case where SITE_ADDR is missing street number prefix' do
        house_details['attributes']['STR_NUM'] = 250
        house_details['attributes']['SITE_ADDR'] = '58th St N'  # No street number in address

        expect(service.send(:extract_street_name)).to eq('58th St N')
      end

      it 'handles addresses with unit numbers' do
        house_details['attributes']['STR_NUM'] = 5924
        house_details['attributes']['SITE_ADDR'] = '5924 5th Ave N # 8'

        expect(service.send(:extract_street_name)).to eq('5th Ave N # 8')
      end

      it 'handles addresses with apartment numbers' do
        house_details['attributes']['STR_NUM'] = 1234
        house_details['attributes']['SITE_ADDR'] = '1234 Main St Apt 2B'

        expect(service.send(:extract_street_name)).to eq('Main St Apt 2B')
      end

      it 'handles addresses with unit designations' do
        house_details['attributes']['STR_NUM'] = 5678
        house_details['attributes']['SITE_ADDR'] = '5678 Oak Dr Unit 3'

        expect(service.send(:extract_street_name)).to eq('Oak Dr Unit 3')
      end

      it 'handles addresses with suite numbers' do
        house_details['attributes']['STR_NUM'] = 9999
        house_details['attributes']['SITE_ADDR'] = '9999 Business Blvd Suite 100'

        expect(service.send(:extract_street_name)).to eq('Business Blvd Suite 100')
      end

      it 'handles addresses with letter units' do
        house_details['attributes']['STR_NUM'] = 1111
        house_details['attributes']['SITE_ADDR'] = '1111 Pine St A'

        expect(service.send(:extract_street_name)).to eq('Pine St A')
      end

      it 'handles addresses with basement units' do
        house_details['attributes']['STR_NUM'] = 2222
        house_details['attributes']['SITE_ADDR'] = '2222 Elm St Bsmt'

        expect(service.send(:extract_street_name)).to eq('Elm St Bsmt')
      end

      it 'handles addresses with floor numbers' do
        house_details['attributes']['STR_NUM'] = 3333
        house_details['attributes']['SITE_ADDR'] = '3333 Maple Ave 2nd Fl'

        expect(service.send(:extract_street_name)).to eq('Maple Ave 2nd Fl')
      end

      it 'handles addresses with complex unit formats' do
        house_details['attributes']['STR_NUM'] = 4444
        house_details['attributes']['SITE_ADDR'] = '4444 Cedar Ln Apt 1B-2'

        expect(service.send(:extract_street_name)).to eq('Cedar Ln Apt 1B-2')
      end

      it 'handles normal address format' do
        house_details['attributes']['STR_NUM'] = 5942
        house_details['attributes']['SITE_ADDR'] = '5942 Burlington Ave N'

        expect(service.send(:extract_street_name)).to eq('Burlington Ave N')
      end

      it 'handles address with no street number in SITE_ADDR' do
        house_details['attributes']['STR_NUM'] = 250
        house_details['attributes']['SITE_ADDR'] = '58th St N'  # No street number in address

        expect(service.send(:extract_street_name)).to eq('58th St N')
      end

      it 'handles address with no street number at all' do
        house_details['attributes']['STR_NUM'] = 0
        house_details['attributes']['SITE_ADDR'] = '58th St N'

        expect(service.send(:extract_street_name)).to eq('58th St N')
      end
    end
  end
end
