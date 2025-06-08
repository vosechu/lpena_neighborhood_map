require 'rails_helper'

RSpec.describe ResidentMailer, type: :mailer do
  let(:user) { create(:user, name: 'Test User', email: 'user@example.com') }
  let(:invited_by_user) { create(:user, name: 'Inviter User', email: 'inviter@example.com') }
  let(:resident) { create(:resident, display_name: 'Test Resident', email: 'resident@example.com', phone: '555-1234') }

  describe '#welcome_new_user' do
    let(:mail) { ResidentMailer.welcome_new_user(resident, user, invited_by_user) }

    it 'renders the headers' do
      expect(mail.subject).to eq("Welcome to the Neighborhood Map - You've been added by #{invited_by_user.name}")
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(['noreply@neighborhoodmap.local'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('Welcome to the Neighborhood Map!')
      expect(mail.body.encoded).to include(user.name)
      expect(mail.body.encoded).to include(invited_by_user.name)
      expect(mail.body.encoded).to include(resident.display_name)
      expect(mail.body.encoded).to include('Set Up Your Account')
    end

    it 'includes resident information' do
      expect(mail.body.encoded).to include(resident.phone) if resident.phone.present?
      expect(mail.body.encoded).to include('Privacy & Opt-Out')
    end

    it 'includes login token in URL' do
      # Mock the token generation
      allow(UserCreationService).to receive(:generate_initial_login_token).with(user).and_return('test-token')
      
      mail = ResidentMailer.welcome_new_user(resident, user, invited_by_user)
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
    let(:updated_by_user) { create(:user, name: 'Updater User', email: 'updater@example.com') }
    let(:mail) { ResidentMailer.data_change_notification(resident, changes, updated_by_user) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Your neighborhood information has been updated')
      expect(mail.to).to eq([resident.email])
      expect(mail.from).to eq(['noreply@neighborhoodmap.local'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('Your Neighborhood Information Has Been Updated')
      expect(mail.body.encoded).to include(resident.display_name)
      expect(mail.body.encoded).to include(updated_by_user.name)
    end

    it 'includes change details' do
      expect(mail.body.encoded).to include('Display name')
      expect(mail.body.encoded).to include('Old Name')
      expect(mail.body.encoded).to include('New Name')
      expect(mail.body.encoded).to include('Phone')
      expect(mail.body.encoded).to include('555-0000')
      expect(mail.body.encoded).to include('555-1234')
    end

    it 'includes current information' do
      expect(mail.body.encoded).to include('Your Current Information')
      expect(mail.body.encoded).to include(resident.email)
    end

    it 'includes opt-out link' do
      expect(mail.body.encoded).to include('Opt out of future notifications')
      expect(mail.body.encoded).to include('/opt-out/')
    end

    it 'includes updater information' do
      expect(mail.body.encoded).to include(updated_by_user.name)
      expect(mail.body.encoded).to include(updated_by_user.email)
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