require 'rails_helper'

RSpec.describe DownloadPropertyDataJob do
  describe '#perform' do
    let(:connection) { instance_double(Connections::PcpaGisConnection) }
    let(:mock_data) do
      {
        'features' => [
          {
            'attributes' => {
              'PCPA_UID' => '123',
              'STR_NUM' => 6573,
              'STR_NAME' => '1ST',
              'SITE_CITYZIP' => 'St Petersburg, FL 33710',
              'LATITUDE' => 27.772074174,
              'LONGITUDE' => -82.728144652,
              'OWNER1' => 'SMITH, JOHN',
              'OWNER2' => 'SMITH, JANE'
            },
            'geometry' => {
              'rings' => [
                [ [ -82.728144652, 27.772074174 ], [ -82.728144652, 27.772074174 ] ]
              ]
            }
          }
        ]
      }
    end

    before do
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      allow(connection).to receive(:fetch_properties).and_return(mock_data)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    around do |example|
      Timecop.freeze(Time.local(2024, 1, 1, 12, 0, 0)) do
        example.run
      end
    end

    it 'creates new houses and residents' do
      expect {
        expect {
          described_class.perform_now
        }.to change(House, :count).by(1)
      }.to change(Resident, :count).by(2)  # Two owners = two residents

      house = House.last
      expect(house.pcpa_uid).to eq('123')
      expect(house.street_number).to eq(6573)
      expect(house.street_name).to eq('1ST')
      expect(house.city).to eq('St Petersburg')
      expect(house.state).to eq('FL')
      expect(house.zip).to eq('33710')
      expect(house.latitude).to be_within(0.000001).of(27.772074174)
      expect(house.longitude).to be_within(0.000001).of(-82.728144652)
      expect(house.boundary_geometry).to eq(mock_data['features'].first['geometry'])

      residents = house.residents.order(:created_at)
      expect(residents.count).to eq(2)

      # First owner
      expect(residents.first.attributes).to include(
        'official_name' => 'SMITH, JOHN',
        'last_seen_at' => nil
      )

      # Second owner
      expect(residents.second.attributes).to include(
        'official_name' => 'SMITH, JANE',
        'last_seen_at' => nil
      )
    end

    context 'when house exists but owners change' do
      let!(:existing_house) do
        House.create!(
          pcpa_uid: '123',
          street_number: 6573,
          street_name: '1ST',
          city: 'St Petersburg',
          state: 'FL',
          zip: '33710',
          latitude: 27.772074174,
          longitude: -82.728144652,
          boundary_geometry: mock_data['features'].first['geometry']
        )
      end
      let!(:old_resident1) do
        existing_house.residents.create!(
          official_name: 'OLD, OWNER1',
          first_seen_at: 1.month.ago
        )
      end
      let!(:old_resident2) do
        existing_house.residents.create!(
          official_name: 'OLD, OWNER2',
          first_seen_at: 1.month.ago
        )
      end

      it 'updates house and creates new residents' do
        expect {
          described_class.perform_now
        }.to change(Resident, :count).by(2)

        [ old_resident1, old_resident2 ].each do |resident|
          resident.reload
          expect(resident.last_seen_at).to eq(Time.current)
        end

        new_residents = existing_house.residents.current.order(:created_at)
        expect(new_residents.map(&:official_name)).to eq([ 'SMITH, JOHN', 'SMITH, JANE' ])
      end
    end

    context 'when an error occurs' do
      let(:error) { StandardError.new('API Error') }

      before do
        allow(connection).to receive(:fetch_properties) do
          Timecop.travel(10.seconds)
          raise error
        end
      end

      it 'logs the error and re-raises it' do
        expect { described_class.perform_now }.to raise_error(StandardError, 'API Error')

        expect(Rails.logger).to have_received(:error).with('Error in DownloadPropertyDataJob after 10.0 seconds: API Error')
        expect(Rails.logger).to have_received(:error).with(error.backtrace.join("\n"))
        expect(Rails.logger).to have_received(:info).with('Download job finished in 10.0 seconds')
      end
    end
  end
end
