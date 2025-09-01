require 'rails_helper'

RSpec.describe ResidentMailer, type: :mailer do
  let(:user) { create(:user, name: 'Test User', email: 'user@example.com') }
  let(:resident) { create(:resident, display_name: 'Test Resident', email: 'resident@example.com', phone: '555-1234') }

  describe '#welcome_new_user' do
    let(:mail) { ResidentMailer.welcome_new_user(resident, user) }
    let(:inviter) { create(:resident, display_name: 'Jane Smith', house: create(:house, street_number: '123', street_name: 'Main St')) }
    let(:mail_with_inviter) { ResidentMailer.welcome_new_user(resident, user, inviter) }

    it 'renders the headers' do
      expect(mail.subject).to eq("Neighborhood Directory Invite from Chuck (6345 Burlington)")
      expect(mail.to).to eq([ user.email ])
      expect(mail.from).to eq([ 'no-reply@lakepasadenaestates.com' ])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('Hi neighbor!')
      expect(mail.body.encoded).to include('white house with the pergola at 6345 Burlington Ave N')
      expect(mail.body.encoded).to include('Set Up Your Account')
    end

    it 'includes inviter information when provided' do
      expect(mail_with_inviter.body.encoded).to include('Your neighbor Jane Smith at 123 Main St thought you might be interested')
      expect(mail_with_inviter.subject).to eq("Neighborhood Directory Invite from Jane Smith (123 Main St)")
    end

    it 'does not include inviter information when not provided' do
      expect(mail.body.encoded).not_to include('Your neighbor')
    end

    it 'includes resident information' do
      expect(mail.body.encoded).to include('Privacy options')
      expect(mail.body.encoded).to include('Unsubscribe from future emails')
    end

    it 'includes login token in URL' do
      # Mock the token generation
      allow(UserCreationService).to receive(:generate_initial_login_token).with(user).and_return('test-token')

      mail = ResidentMailer.welcome_new_user(resident, user)
      expect(mail.body.encoded).to include('test-token')
    end
  end

  describe '#data_change_notification' do
    let(:changes) do
      {
        'display_name' => { from: 'Old Name', to: 'New Name' },
        'phone' => { from: '555-0000', to: '555-1234' }
      }
    end
    let(:mail) { ResidentMailer.data_change_notification(resident, changes) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Your neighborhood information has been updated')
      expect(mail.to).to eq([ resident.email ])
      expect(mail.from).to eq([ 'no-reply@lakepasadenaestates.com' ])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('Your neighborhood information has been updated')
      expect(mail.body.encoded).to include(resident.display_name)
    end

    it 'includes change details' do
      expect(mail.body.encoded).to include('Display name')
      expect(mail.body.encoded).to include('Old Name')
      expect(mail.body.encoded).to include('New Name')
      expect(mail.body.encoded).to include('Phone')
      expect(mail.body.encoded).to include('555-0000')
      expect(mail.body.encoded).to include('555-1234')
    end

    it 'includes correcting information' do
      expect(mail.body.encoded).to include('Correcting or hiding information')
      expect(mail.body.encoded).to include('vosechu@gmail.com')
    end

    it 'includes opt-out link' do
      expect(mail.body.encoded).to include('Remove me from the directory')
      expect(mail.body.encoded).to include('/opt-out/')
    end

    it 'includes community message' do
      expect(mail.body.encoded).to include('run by neighbors, for neighbors')
    end
  end

  describe '#house_transition_notification' do
    let(:house) { create(:house, street_number: '123', street_name: 'Main St') }
    let(:old_resident) { create(:resident, official_name: 'John Doe', house: house) }
    let(:new_resident) { create(:resident, official_name: 'Jane Smith', house: house) }
    let(:changes) do
      {
        residents_removed: [old_resident],
        residents_added: [new_resident]
      }
    end
    let(:mail) { ResidentMailer.house_transition_notification(house, changes) }

    it 'renders the headers' do
      expect(mail.subject).to eq('House ownership change: 123 Main St')
      expect(mail.to).to eq(['chuck@lakepasadenaestates.com'])
      expect(mail.from).to eq(['no-reply@lakepasadenaestates.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('House Ownership Change Detected')
      expect(mail.body.encoded).to include('123 Main St')
    end

    it 'includes previous residents' do
      expect(mail.body.encoded).to include('Previous Residents')
      expect(mail.body.encoded).to include('John Doe')
    end

    it 'includes new residents' do
      expect(mail.body.encoded).to include('New Residents')
      expect(mail.body.encoded).to include('Jane Smith')
    end

    it 'includes PCPAO verification link' do
      expect(mail.body.encoded).to include('Search PCPAO Property Records')
      expect(mail.body.encoded).to include('pcpao.gov/quick-search')
      expect(mail.body.encoded).to include('Search for:</strong> 123 Main St')
    end

    context 'when admin_email is configured in credentials' do
      before do
        allow(Rails.application.credentials).to receive(:admin_email).and_return('admin@example.com')
      end

      it 'uses the configured admin email' do
        expect(mail.to).to eq(['admin@example.com'])
      end
    end
  end

  describe '#generate_opt_out_token' do
    it 'generates a valid token' do
      mailer = ResidentMailer.new
      token = mailer.send(:generate_opt_out_token, resident)

      expect(token).to be_present

      # Verify token can be decoded
      decoded = Rails.application.message_verifier(:opt_out).verify(token)
      expect(decoded['resident_id']).to eq(resident.id)
      expect(decoded['expires_at']).to be_present
    end
  end
end
