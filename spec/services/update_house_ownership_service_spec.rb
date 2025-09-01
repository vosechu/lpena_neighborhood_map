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
        allow(ActiveRecord::Base).to receive(:transaction).and_yield
      end

      context 'complete ownership change (no names in common)' do
        before do
          allow(service).to receive(:mark_all_residents_as_moved_out)
          allow(service).to receive(:create_arriving_residents)
        end

        it 'performs transaction and categorizes changes' do
          result = service.call
          expect(ActiveRecord::Base).to have_received(:transaction)
          expect(result).to eq({ residents_added: [], residents_removed: [] })
        end

        it 'calls mark_all_residents_as_moved_out for complete change' do
          service.call
          expect(service).to have_received(:mark_all_residents_as_moved_out)
        end

        it 'calls create_arriving_residents when arriving names present' do
          service.call
          expect(service).to have_received(:create_arriving_residents)
        end
      end

      context 'partial ownership change (some names in common)' do
        let(:owner1_name) { 'OLD, OWNER' }  # Keeping one existing owner
        let(:owner2_name) { 'NEW, OWNER' }  # Adding one new owner

        before do
          allow(service).to receive(:mark_specific_residents_as_moved_out)
          allow(service).to receive(:create_arriving_residents)
        end

        it 'calls mark_specific_residents_as_moved_out for partial change' do
          service.call
          expect(service).to have_received(:mark_specific_residents_as_moved_out)
        end
      end

      it 'sends house transition notification when changes occur' do
        # Mock the methods that will be called
        allow(service).to receive(:mark_all_residents_as_moved_out)
        allow(service).to receive(:create_arriving_residents)

        # Set up the changes that would be made
        service.instance_variable_set(:@changes, { residents_added: [ new_resident1 ], residents_removed: [ old_resident1 ] })
        expect(ResidentMailer).to receive(:house_transition_notification).with(house, { residents_added: [ new_resident1 ], residents_removed: [ old_resident1 ] }).and_return(double(deliver_later: true))

        service.call
      end

      context 'when no new owners specified' do
        let(:owner1_name) { nil }
        let(:owner2_name) { nil }

        it 'does not call create_arriving_residents' do
          # Mock all the methods that would be called
          allow(service).to receive(:mark_all_residents_as_moved_out)
          allow(service).to receive(:mark_specific_residents_as_moved_out)
          allow(service).to receive(:create_arriving_residents)

          # Mock the residents so update! doesn't fail
          current_owners = service.instance_variable_get(:@current_owners)
          current_owners.each { |resident| allow(resident).to receive(:update!) }

          service.call
          expect(service).not_to have_received(:create_arriving_residents)
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

  describe '#categorize_name_changes' do
    let(:owner1_name) { 'SMITH, JOHN' }
    let(:owner2_name) { 'DOE, JANE' }

    context 'complete ownership change (no overlap)' do
      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'OLD, OWNER'),
          instance_double(Resident, official_name: 'PREVIOUS, OWNER')
        ])
      end

      it 'correctly categorizes complete change' do
        service.categorize_name_changes

        expect(service.instance_variable_get(:@staying_names).to_a).to eq([])
        expect(service.instance_variable_get(:@leaving_names).to_a.sort).to eq([ 'OLD, OWNER', 'PREVIOUS, OWNER' ])
        expect(service.instance_variable_get(:@arriving_names).to_a.sort).to eq([ 'DOE, JANE', 'SMITH, JOHN' ])
        expect(service.instance_variable_get(:@complete_change)).to be true
      end
    end

    context 'partial ownership change (some overlap)' do
      let(:owner1_name) { 'OLD, OWNER' }    # Keeping this one
      let(:owner2_name) { 'NEW, OWNER' }    # Adding this one

      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'OLD, OWNER'),
          instance_double(Resident, official_name: 'PREVIOUS, OWNER')
        ])
      end

      it 'correctly categorizes partial change' do
        service.categorize_name_changes

        expect(service.instance_variable_get(:@staying_names).to_a).to eq([ 'OLD, OWNER' ])
        expect(service.instance_variable_get(:@leaving_names).to_a).to eq([ 'PREVIOUS, OWNER' ])
        expect(service.instance_variable_get(:@arriving_names).to_a).to eq([ 'NEW, OWNER' ])
        expect(service.instance_variable_get(:@complete_change)).to be false
      end
    end

    context 'addition only (no one leaves)' do
      let(:owner1_name) { 'OLD, OWNER' }
      let(:owner2_name) { 'PREVIOUS, OWNER' }

      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'OLD, OWNER')
        ])
      end

      it 'correctly categorizes addition' do
        service.categorize_name_changes

        expect(service.instance_variable_get(:@staying_names).to_a).to eq([ 'OLD, OWNER' ])
        expect(service.instance_variable_get(:@leaving_names).to_a).to eq([])
        expect(service.instance_variable_get(:@arriving_names).to_a).to eq([ 'PREVIOUS, OWNER' ])
        expect(service.instance_variable_get(:@complete_change)).to be false
      end
    end

    context 'removal only (no one arrives)' do
      let(:owner1_name) { 'OLD, OWNER' }
      let(:owner2_name) { nil }

      before do
        service.instance_variable_set(:@current_owners, [
          instance_double(Resident, official_name: 'OLD, OWNER'),
          instance_double(Resident, official_name: 'PREVIOUS, OWNER')
        ])
      end

      it 'correctly categorizes removal' do
        service.categorize_name_changes

        expect(service.instance_variable_get(:@staying_names).to_a).to eq([ 'OLD, OWNER' ])
        expect(service.instance_variable_get(:@leaving_names).to_a).to eq([ 'PREVIOUS, OWNER' ])
        expect(service.instance_variable_get(:@arriving_names).to_a).to eq([])
        expect(service.instance_variable_get(:@complete_change)).to be false
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

  describe '#mark_all_residents_as_moved_out' do
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
      service.send(:mark_all_residents_as_moved_out)
      expect(resident1).to have_received(:update!).with(moved_out_at: current_time)
      expect(resident2).to have_received(:update!).with(moved_out_at: current_time)
    end

    it 'adds residents to changes hash' do
      service.send(:mark_all_residents_as_moved_out)
      expect(service.instance_variable_get(:@changes)[:residents_removed]).to eq([ resident1, resident2 ])
    end
  end

  describe '#create_arriving_residents' do
    let(:owner1_name) { 'SMITH, JOHN' }
    let(:owner2_name) { 'DOE, JANE' }
    let(:resident1) { instance_double(Resident, id: 1, official_name: 'SMITH, JOHN') }
    let(:resident2) { instance_double(Resident, id: 2, official_name: 'DOE, JANE') }

    before do
      # Set up arriving names (which would be set by categorize_name_changes)
      service.instance_variable_set(:@arriving_names, [ 'SMITH, JOHN', 'DOE, JANE' ])
      allow(service).to receive(:create_resident).with('SMITH, JOHN').and_return(resident1)
      allow(service).to receive(:create_resident).with('DOE, JANE').and_return(resident2)
    end

    it 'creates residents for all arriving names' do
      service.send(:create_arriving_residents)
      expect(service).to have_received(:create_resident).with('SMITH, JOHN')
      expect(service).to have_received(:create_resident).with('DOE, JANE')
    end

    it 'adds residents to changes hash' do
      service.send(:create_arriving_residents)
      expect(service.instance_variable_get(:@changes)[:residents_added]).to eq([ resident1, resident2 ])
    end

    context 'when no arriving names' do
      before do
        service.instance_variable_set(:@arriving_names, [])
      end

      it 'creates no residents' do
        service.send(:create_arriving_residents)
        expect(service).not_to have_received(:create_resident)
      end
    end

    context 'with real data patterns' do
      context 'with business entities' do
        before do
          service.instance_variable_set(:@arriving_names, [ 'SMITH FAMILY TRUST', 'ABC LLC' ])
          allow(service).to receive(:create_resident).with('SMITH FAMILY TRUST').and_return(instance_double(Resident))
          allow(service).to receive(:create_resident).with('ABC LLC').and_return(instance_double(Resident))
        end

        it 'creates residents for business entities' do
          service.send(:create_arriving_residents)
          expect(service).to have_received(:create_resident).with('SMITH FAMILY TRUST')
          expect(service).to have_received(:create_resident).with('ABC LLC')
        end
      end

      context 'with government entities' do
        before do
          service.instance_variable_set(:@arriving_names, [ 'CITY OF ST PETERSBURG' ])
          allow(service).to receive(:create_resident).with('CITY OF ST PETERSBURG').and_return(instance_double(Resident))
        end

        it 'creates residents for government entities' do
          service.send(:create_arriving_residents)
          expect(service).to have_received(:create_resident).with('CITY OF ST PETERSBURG')
        end
      end

      context 'with special characters' do
        before do
          service.instance_variable_set(:@arriving_names, [ 'SMITH, JOHN JR.', 'DOE & JANE' ])
          allow(service).to receive(:create_resident).with('SMITH, JOHN JR.').and_return(instance_double(Resident))
          allow(service).to receive(:create_resident).with('DOE & JANE').and_return(instance_double(Resident))
        end

        it 'creates residents with special characters' do
          service.send(:create_arriving_residents)
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
