require 'rails_helper'

RSpec.describe DownloadPropertyDataJob do
  describe '#perform' do
    it 'fetches property data from the PCPA GIS connection' do
      connection = instance_double(Connections::PcpaGisConnection)
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      expect(connection).to receive(:fetch_properties).and_return('features' => [])

      described_class.perform_now
    end

    it 'calls HouseImportService for each property' do
      connection = instance_double(Connections::PcpaGisConnection)
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      features = [
        { 'attributes' => { 'SITE_ADDR' => '123 Main St' } },
        { 'attributes' => { 'SITE_ADDR' => '456 Oak Ave' } }
      ]
      allow(connection).to receive(:fetch_properties).and_return('features' => features)
      allow(UpdateHouseOwnershipService).to receive(:call).and_return({ residents_added: [], residents_removed: [] })
      expect(HouseImportService).to receive(:call).with(features[0]).ordered
      expect(HouseImportService).to receive(:call).with(features[1]).ordered

      described_class.perform_now
    end

    it 'calls UpdateHouseOwnershipService for each property' do
      connection = instance_double(Connections::PcpaGisConnection)
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      features = [
        { 'attributes' => { 'SITE_ADDR' => '123 Main St', 'OWNER1' => 'A', 'OWNER2' => 'B' } },
        { 'attributes' => { 'SITE_ADDR' => '456 Oak Ave', 'OWNER1' => 'C', 'OWNER2' => 'D' } }
      ]
      allow(connection).to receive(:fetch_properties).and_return('features' => features)
      house1 = instance_double(House)
      house2 = instance_double(House)
      allow(HouseImportService).to receive(:call).with(features[0]).and_return(house1)
      allow(HouseImportService).to receive(:call).with(features[1]).and_return(house2)

      # Verify that UpdateHouseOwnershipService is called with the correct arguments
      # extracted from the attributes
      expect(UpdateHouseOwnershipService).to receive(:call).with(
        house: house1,
        owner1: 'A',
        owner2: 'B'
      ).ordered
      expect(UpdateHouseOwnershipService).to receive(:call).with(
        house: house2,
        owner1: 'C',
        owner2: 'D'
      ).ordered

      described_class.perform_now
    end

    it 'bails out if the PCPA GIS connection fails' do
      connection = instance_double(Connections::PcpaGisConnection)
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      allow(connection).to receive(:fetch_properties).and_raise(StandardError, 'Connection failed')

      expect { described_class.perform_now }.to raise_error(StandardError, 'Connection failed')
    end

    it 'continues processing other properties if a single property raises an error' do
      connection = instance_double(Connections::PcpaGisConnection)
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      features = [
        { 'attributes' => { 'SITE_ADDR' => '123 Main St', 'OWNER1' => 'A', 'OWNER2' => 'B' } },
        { 'attributes' => { 'SITE_ADDR' => '456 Oak Ave', 'OWNER1' => 'C', 'OWNER2' => 'D' } }
      ]
      allow(connection).to receive(:fetch_properties).and_return('features' => features)

      # First property fails, second succeeds
      allow(HouseImportService).to receive(:call).with(features[0]).and_raise(StandardError, 'Import failed')
      house2 = instance_double(House)
      allow(HouseImportService).to receive(:call).with(features[1]).and_return(house2)
      allow(UpdateHouseOwnershipService).to receive(:call).with(house: house2, owner1: 'C', owner2: 'D')

      # Should not raise an error, should continue processing
      expect { described_class.perform_now }.not_to raise_error
    end

    it 'handles empty property data gracefully' do
      connection = instance_double(Connections::PcpaGisConnection)
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      allow(connection).to receive(:fetch_properties).and_return('features' => [])

      # Should not call any services when no properties to process
      expect(HouseImportService).not_to receive(:call)
      expect(UpdateHouseOwnershipService).not_to receive(:call)

      described_class.perform_now
    end

    it 'handles missing attributes in property data gracefully' do
      connection = instance_double(Connections::PcpaGisConnection)
      allow(Connections::PcpaGisConnection).to receive(:new).and_return(connection)
      features = [
        { 'attributes' => { 'SITE_ADDR' => '123 Main St' } }, # Missing OWNER1, OWNER2
        { 'attributes' => { 'OWNER1' => 'A', 'OWNER2' => 'B' } } # Missing SITE_ADDR
      ]
      allow(connection).to receive(:fetch_properties).and_return('features' => features)

      # Should handle missing attributes gracefully
      allow(HouseImportService).to receive(:call).and_raise(StandardError, 'Missing required attributes')
      allow(UpdateHouseOwnershipService).to receive(:call).and_raise(StandardError, 'Missing required attributes')

      # Should not raise an error, should continue processing
      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
