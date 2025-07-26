require 'rails_helper'

RSpec.describe ApartmentDenylistService do
  describe '.should_skip?' do
    context 'when address is in denylist' do
      let(:house_details) do
        {
          'attributes' => {
            'STR_NUM' => '5900',
            'SITE_ADDR' => '5900 5th Ave N'
          }
        }
      end

      it 'returns true' do
        expect(described_class.should_skip?(house_details)).to be true
      end
    end

    context 'when address is not in denylist' do
      let(:house_details) do
        {
          'attributes' => {
            'STR_NUM' => '123',
            'SITE_ADDR' => '123 Main St'
          }
        }
      end

      it 'returns false' do
        expect(described_class.should_skip?(house_details)).to be false
      end
    end

    context 'when address partially matches denylist' do
      let(:house_details) do
        {
          'attributes' => {
            'STR_NUM' => '5901',
            'SITE_ADDR' => '5901 5th Ave N'
          }
        }
      end

      it 'returns false' do
        expect(described_class.should_skip?(house_details)).to be false
      end
    end

    context 'when denylist contains different address' do
      let(:house_details) do
        {
          'attributes' => {
            'STR_NUM' => '0',
            'SITE_ADDR' => '5th Ave N'
          }
        }
      end

      it 'returns true for denylisted address' do
        stub_const("#{described_class}::DENYLISTED_ADDRESSES", [ '0 5th Ave N', '5th Ave N' ])

        expect(described_class.should_skip?(house_details)).to be true
      end
    end

    context 'when there is a unit number' do
      let(:house_details) do
        {
          'attributes' => { 'STR_NUM' => '5900', 'SITE_ADDR' => '5900 5th Ave N #D7' }
        }
      end

      it 'returns false for units at a denylisted address' do
        expect(described_class.should_skip?(house_details)).to be false
      end
    end
  end
end
