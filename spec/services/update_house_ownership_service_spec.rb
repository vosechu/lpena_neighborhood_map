require 'rails_helper'

RSpec.describe UpdateHouseOwnershipService do
  let(:house) { instance_double(House, id: 123) }
  let(:current_time) { Time.current }
  let(:service) { described_class.new(house: house, owner1_name: owner1_name, owner2_name: owner2_name) }

  around do |example|
    Timecop.freeze(current_time) do
      example.run
    end
  end

  describe '#call' do
    context 'when ownership has not changed' do
      let(:owner1_name) { 'SMITH, JOHN' }
      let(:owner2_name) { nil }

      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'SMITH, JOHN')
        ])
        service.instance_variable_set(:@owner1_name, 'SMITH, JOHN')
        service.instance_variable_set(:@owner2_name, nil)
      end

      it 'returns empty changes hash' do
        result = service.call
        expect(result).to eq({ residents_added: [], residents_removed: [] })
      end

      it 'does not perform any database operations' do
        expect(ActiveRecord::Base).not_to receive(:transaction)
        service.call
      end
    end

    context 'when ownership has changed' do
      let(:owner1_name) { 'NEW, OWNER' }
      let(:owner2_name) { 'SECOND, OWNER' }
      let(:old_resident1) { instance_double(Resident, id: 1, official_name: 'OLD, OWNER') }
      let(:old_resident2) { instance_double(Resident, id: 2, official_name: 'ANOTHER, OWNER') }
      let(:new_resident1) { instance_double(Resident, id: 3, official_name: 'NEW, OWNER') }
      let(:new_resident2) { instance_double(Resident, id: 4, official_name: 'SECOND, OWNER') }

      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'OLD, OWNER'),
          instance_double(Resident, official_name: 'ANOTHER, OWNER')
        ])
        service.instance_variable_set(:@owner1_name, 'NEW, OWNER')
        service.instance_variable_set(:@owner2_name, 'SECOND, OWNER')
        allow(service).to receive(:mark_current_residents_as_moved_out)
        allow(service).to receive(:create_new_residents)
        allow(ActiveRecord::Base).to receive(:transaction).and_yield
      end

      it 'performs transaction and returns changes' do
        result = service.call
        expect(ActiveRecord::Base).to have_received(:transaction)
        expect(result).to eq({ residents_added: [], residents_removed: [] })
      end

      it 'calls mark_current_residents_as_moved_out' do
        service.call
        expect(service).to have_received(:mark_current_residents_as_moved_out)
      end

      it 'calls create_new_residents when owner1_name is present' do
        service.call
        expect(service).to have_received(:create_new_residents)
      end

      it 'sends house transition notification when changes occur' do
        service.instance_variable_set(:@changes, { residents_added: [new_resident1], residents_removed: [old_resident1] })
        expect(ResidentMailer).to receive(:house_transition_notification).with(house, { residents_added: [new_resident1], residents_removed: [old_resident1] }).and_return(double(deliver_later: true))
        
        service.call
      end

      context 'when owner1_name is nil' do
        let(:owner1_name) { nil }
        let(:owner2_name) { nil }

        it 'does not call create_new_residents' do
          service.instance_variable_set(:@owner1_name, nil)
          service.instance_variable_set(:@owner2_name, nil)
          service.call
          expect(service).not_to have_received(:create_new_residents)
        end
      end
    end
  end

  describe '#current_owner_names' do
    let(:owner1_name) { 'SMITH, JOHN' }
    let(:owner2_name) { 'DOE, JANE' }
    let(:resident1) { instance_double(Resident, official_name: 'SMITH, JOHN') }
    let(:resident2) { instance_double(Resident, official_name: 'DOE, JANE') }
    let(:current_owners) { [ resident1, resident2 ] }

    before do
      service.instance_variable_set(:@current_owners, current_owners)
    end

    it 'returns normalized and sorted owner names' do
      result = service.current_owner_names
      expect(result).to eq([ 'DOE, JANE', 'SMITH, JOHN' ])
    end

    context 'with nil official names' do
      let(:resident1) { instance_double(Resident, official_name: nil) }
      let(:resident2) { instance_double(Resident, official_name: 'DOE, JANE') }

      it 'filters out nil names' do
        result = service.current_owner_names
        expect(result).to eq([ 'DOE, JANE' ])
      end
    end

    context 'with whitespace in names' do
      let(:resident1) { instance_double(Resident, official_name: '  SMITH, JOHN  ') }
      let(:resident2) { instance_double(Resident, official_name: 'DOE, JANE') }

      it 'strips whitespace' do
        result = service.current_owner_names
        expect(result).to eq([ 'DOE, JANE', 'SMITH, JOHN' ])
      end
    end
  end

  describe '#new_owner_names' do
    let(:owner1_name) { 'SMITH, JOHN' }
    let(:owner2_name) { 'DOE, JANE' }

    it 'returns normalized and sorted owner names' do
      result = service.new_owner_names
      expect(result).to eq([ 'DOE, JANE', 'SMITH, JOHN' ])
    end

    context 'with nil owners' do
      let(:owner1_name) { nil }
      let(:owner2_name) { 'DOE, JANE' }

      it 'filters out nil owners' do
        result = service.new_owner_names
        expect(result).to eq([ 'DOE, JANE' ])
      end
    end

    context 'with whitespace in names' do
      let(:owner1_name) { '  SMITH, JOHN  ' }
      let(:owner2_name) { 'DOE, JANE' }

      it 'strips whitespace' do
        result = service.new_owner_names
        expect(result).to eq([ 'DOE, JANE', 'SMITH, JOHN' ])
      end
    end

    context 'with empty string owners' do
      let(:owner1_name) { '' }
      let(:owner2_name) { 'DOE, JANE' }

      it 'filters out empty string owners' do
        result = service.new_owner_names
        expect(result).to eq([ 'DOE, JANE' ])
      end
    end
  end

  describe '#ownership_changed?' do
    let(:owner1_name) { 'SMITH, JOHN' }
    let(:owner2_name) { 'DOE, JANE' }

    context 'when current and new owners match' do
      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'SMITH, JOHN'),
          instance_double(Resident, official_name: 'DOE, JANE')
        ])
      end
      it 'returns false' do
        expect(service.ownership_changed?).to be false
      end
    end

    context 'when current and new owners differ' do
      let(:owner1_name) { 'NEW, OWNER' }
      let(:owner2_name) { nil }

      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'OLD, OWNER')
        ])
      end
      it 'returns true' do
        expect(service.ownership_changed?).to be true
      end
    end

    context 'with real data patterns' do
      context 'with case differences' do
        let(:owner1_name) { 'SMITH, JOHN' }
        let(:owner2_name) { nil }

        before do
          service.instance_variable_set(:@current_owners, [
            instance_double(Resident, official_name: 'smith, john')
          ])
        end
        it 'normalizes case for comparison' do
          expect(service.ownership_changed?).to be false
        end
      end

      context 'with whitespace differences' do
        let(:owner1_name) { 'SMITH, JOHN' }
        let(:owner2_name) { nil }

        before do
          service.instance_variable_set(:@current_owners, [
            instance_double(Resident, official_name: '  SMITH, JOHN  ')
          ])
        end
        it 'normalizes whitespace for comparison' do
          expect(service.ownership_changed?).to be false
        end
      end

      context 'with nil values' do
        let(:owner1_name) { nil }
        let(:owner2_name) { nil }

        before do
          service.instance_variable_set(:@current_owners, [])
        end
        it 'handles nil values correctly' do
          expect(service.ownership_changed?).to be false
        end
      end

      context 'with empty string values' do
        let(:owner1_name) { '' }
        let(:owner2_name) { '   ' }

        before do
          service.instance_variable_set(:@current_owners, [])
        end
        it 'handles empty strings correctly' do
          expect(service.ownership_changed?).to be false
        end
      end

      context 'with business entities' do
        let(:owner1_name) { 'SMITH FAMILY TRUST' }
        let(:owner2_name) { nil }

        before do
          service.instance_variable_set(:@current_owners, [
            instance_double(Resident, official_name: 'SMITH FAMILY TRUST')
          ])
        end
        it 'handles business entity names' do
          expect(service.ownership_changed?).to be false
        end
      end

      context 'with government entities' do
        let(:owner1_name) { 'CITY OF ST PETERSBURG' }
        let(:owner2_name) { nil }

        before do
          service.instance_variable_set(:@current_owners, [
            instance_double(Resident, official_name: 'CITY OF ST PETERSBURG')
          ])
        end
        it 'handles government entity names' do
          expect(service.ownership_changed?).to be false
        end
      end

      context 'with special characters' do
        let(:owner1_name) { 'SMITH, JOHN JR.' }
        let(:owner2_name) { nil }

        before do
          service.instance_variable_set(:@current_owners, [
            instance_double(Resident, official_name: 'SMITH, JOHN JR.')
          ])
        end
        it 'handles names with special characters' do
          expect(service.ownership_changed?).to be false
        end
        it 'handles names with ampersands' do
          ampersand_service = described_class.new(house: house, owner1_name: 'DOE & JANE', owner2_name: nil)
          ampersand_service.instance_variable_set(:@current_owners, [
            instance_double(Resident, official_name: 'DOE & JANE')
          ])
          expect(ampersand_service.ownership_changed?).to be false
        end
      end

      context 'with multiple owners' do
        let(:owner1_name) { 'DOE, JANE' }
        let(:owner2_name) { 'SMITH, JOHN' }

        before do
          service.instance_variable_set(:@current_owners, [
            instance_double(Resident, official_name: 'SMITH, JOHN'),
            instance_double(Resident, official_name: 'DOE, JANE')
          ])
        end
        it 'handles multiple owners in different orders' do
          expect(service.ownership_changed?).to be false
        end
      end
    end
  end

  describe '#mark_current_residents_as_moved_out' do
    let(:owner1_name) { 'NEW, OWNER' }
    let(:resident1) { instance_double(Resident, id: 1, house_id: house.id) }
    let(:resident2) { instance_double(Resident, id: 2, house_id: house.id) }
    let(:current_residents) { [ resident1, resident2 ] }

    before do
      service.instance_variable_set(:@current_residents, current_residents)
      allow(resident1).to receive(:update!)
      allow(resident2).to receive(:update!)
    end

    let(:owner2_name) { nil }
    let(:service) { described_class.new(house: house, owner1_name: owner1_name, owner2_name: owner2_name) }

    it 'marks all current residents as moved out' do
      service.send(:mark_current_residents_as_moved_out)
      expect(resident1).to have_received(:update!).with(moved_out_at: current_time)
      expect(resident2).to have_received(:update!).with(moved_out_at: current_time)
    end

    it 'adds residents to changes hash' do
      service.send(:mark_current_residents_as_moved_out)
      expect(service.instance_variable_get(:@changes)[:residents_removed]).to eq([ resident1, resident2 ])
    end
  end

  describe '#create_new_residents' do
    let(:owner1_name) { 'SMITH, JOHN' }
    let(:owner2_name) { 'DOE, JANE' }
    let(:resident1) { instance_double(Resident, id: 1, official_name: 'SMITH, JOHN') }
    let(:resident2) { instance_double(Resident, id: 2, official_name: 'DOE, JANE') }

    before do
      allow(service).to receive(:create_resident).with('SMITH, JOHN').and_return(resident1)
      allow(service).to receive(:create_resident).with('DOE, JANE').and_return(resident2)
    end

    it 'creates residents for both owners' do
      service.send(:create_new_residents)
      expect(service).to have_received(:create_resident).with('SMITH, JOHN')
      expect(service).to have_received(:create_resident).with('DOE, JANE')
    end

    it 'adds residents to changes hash' do
      service.send(:create_new_residents)
      expect(service.instance_variable_get(:@changes)[:residents_added]).to eq([ resident1, resident2 ])
    end

    context 'when owner1_name is empty' do
      let(:owner1_name) { '   ' }

      it 'does not create resident for empty owner1_name' do
        service.send(:create_new_residents)
        expect(service).not_to have_received(:create_resident).with('   ')
      end
    end

    context 'when owner2_name is nil' do
      let(:owner2_name) { nil }

      it 'only creates resident for owner1_name' do
        service.send(:create_new_residents)
        expect(service).to have_received(:create_resident).with('SMITH, JOHN')
        expect(service).not_to have_received(:create_resident).with(nil)
      end
    end

    context 'with real data patterns' do
      context 'with business entities' do
        let(:owner1_name) { 'SMITH FAMILY TRUST' }
        let(:owner2_name) { 'ABC LLC' }
        let(:resident1) { instance_double(Resident, id: 1, official_name: 'SMITH FAMILY TRUST') }
        let(:resident2) { instance_double(Resident, id: 2, official_name: 'ABC LLC') }

        before do
          allow(service).to receive(:create_resident).with('SMITH FAMILY TRUST').and_return(resident1)
          allow(service).to receive(:create_resident).with('ABC LLC').and_return(resident2)
        end

        it 'creates residents for business entities' do
          service.send(:create_new_residents)
          expect(service).to have_received(:create_resident).with('SMITH FAMILY TRUST')
          expect(service).to have_received(:create_resident).with('ABC LLC')
        end
      end

      context 'with government entities' do
        let(:owner1_name) { 'CITY OF ST PETERSBURG' }
        let(:resident1) { instance_double(Resident, id: 1, official_name: 'CITY OF ST PETERSBURG') }

        before do
          allow(service).to receive(:create_resident).with('CITY OF ST PETERSBURG').and_return(resident1)
        end

        it 'creates residents for government entities' do
          service.send(:create_new_residents)
          expect(service).to have_received(:create_resident).with('CITY OF ST PETERSBURG')
        end
      end

      context 'with special characters' do
        let(:owner1_name) { 'SMITH, JOHN JR.' }
        let(:owner2_name) { 'DOE & JANE' }
        let(:resident1) { instance_double(Resident, id: 1, official_name: 'SMITH, JOHN JR.') }
        let(:resident2) { instance_double(Resident, id: 2, official_name: 'DOE & JANE') }

        before do
          allow(service).to receive(:create_resident).with('SMITH, JOHN JR.').and_return(resident1)
          allow(service).to receive(:create_resident).with('DOE & JANE').and_return(resident2)
        end

        it 'creates residents with special characters' do
          service.send(:create_new_residents)
          expect(service).to have_received(:create_resident).with('SMITH, JOHN JR.')
          expect(service).to have_received(:create_resident).with('DOE & JANE')
        end
      end
    end
  end

  describe '#create_resident' do
    let(:owner1_name) { 'SMITH, JOHN' }
    let(:owner2_name) { nil }
    let(:service) { described_class.new(house: house, owner1_name: owner1_name, owner2_name: owner2_name) }
    let(:resident) { instance_double(Resident, id: 1, official_name: 'SMITH, JOHN') }
    let(:residents_association) { instance_double(ActiveRecord::Associations::CollectionProxy) }

    before do
      allow(house).to receive(:residents).and_return(residents_association)
      allow(residents_association).to receive(:create!).and_return(resident)
    end

    it 'creates resident with correct attributes' do
      service.send(:create_resident, 'SMITH, JOHN')
      expect(residents_association).to have_received(:create!).with(
        official_name: 'SMITH, JOHN',
        first_seen_at: current_time
      )
    end

    context 'with blank name' do
      it 'raises ArgumentError for blank name' do
        expect { service.send(:create_resident, '') }.to raise_error(ArgumentError, 'official_name is required for imported residents')
      end

      it 'raises ArgumentError for nil name' do
        expect { service.send(:create_resident, nil) }.to raise_error(ArgumentError, 'official_name is required for imported residents')
      end

      it 'raises ArgumentError for whitespace-only name' do
        expect { service.send(:create_resident, '   ') }.to raise_error(ArgumentError, 'official_name is required for imported residents')
      end
    end
  end
end
