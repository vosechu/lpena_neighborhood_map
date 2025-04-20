require 'rails_helper'

RSpec.describe DownloadPropertyDataJob do
  describe '#perform' do
    let(:connection) { instance_double(Connections::PcpaGisConnection) }
    let(:mock_data) do
      {
        'features' => [
          { 'attributes' => { 'PROPERTY_ID' => '123' } },
          { 'attributes' => { 'PROPERTY_ID' => '456' } }
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

    it 'downloads and processes property data' do
      expect(connection).to receive(:fetch_properties) do
        Timecop.travel(10.seconds)
        mock_data
      end

      result = described_class.perform_now

      expect(result).to eq(mock_data)
      expect(Rails.logger).to have_received(:info).with('Starting property data download job')
      expect(Rails.logger).to have_received(:info).with('Fetching properties from PCPA GIS service...')
      expect(Rails.logger).to have_received(:info).with('Successfully downloaded 2 properties in 10.0 seconds')
      expect(Rails.logger).to have_received(:info).with('Download job finished in 10.0 seconds')
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
