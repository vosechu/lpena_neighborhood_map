require 'rails_helper'

RSpec.describe ResidentMailer, type: :mailer do
  let(:user) { create(:user, name: 'Test User', email: 'user@example.com') }
  let(:resident) { create(:resident, display_name: 'Test Resident', email: 'resident@example.com', phone: '555-1234') }

  describe '#welcome_new_user' do
    let(:mail) { ResidentMailer.welcome_new_user(resident, user) }

    it 'renders the headers' do
      expect(mail.subject).to eq("Welcome to the Neighborhood Directory - Set up your account")
      expect(mail.to).to eq([ user.email ])
      expect(mail.from).to eq([ 'no-reply@lakepasadenaestates.com' ])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('Hi there!')
      expect(mail.body.encoded).to include('I\'m your neighbor at 63rd and Burlington Ave N')
      expect(mail.body.encoded).to include('Set Up Your Account')
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
