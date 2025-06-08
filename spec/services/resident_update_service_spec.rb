require 'rails_helper'

RSpec.describe ResidentUpdateService, type: :service do
  let(:user) { create(:user, email: 'test-user@example.com') }
  let(:resident) { create(:resident, :without_email) }

  describe '.update_resident' do
    context 'when updating basic information' do
      let(:params) { { display_name: 'Updated Name' } }

      it 'updates the resident successfully' do
        expect(ResidentUpdateService.update_resident(resident, params, user)).to be true
        expect(resident.reload.display_name).to eq('Updated Name')
      end

      it 'returns false if update fails' do
        allow(resident).to receive(:update).and_return(false)
        expect(ResidentUpdateService.update_resident(resident, params, user)).to be false
      end
    end

    context 'when adding an email to a resident' do
      let(:params) { { email: 'new@example.com' } }

      it 'creates a new user for the resident' do
        initial_count = User.count
        
        expect {
          ResidentUpdateService.update_resident(resident, params, user)
        }.to change(User, :count).by(1)

        new_user = User.find_by(email: 'new@example.com')
        expect(new_user).to be_present
        expect(new_user.name).to eq(resident.display_name)
        expect(resident.reload.user).to eq(new_user)
      end

      it 'sends a welcome email' do
        # Mock the email delivery
        allow(ResidentMailer).to receive(:welcome_new_user).and_return(double(deliver_later: true))
        
        ResidentUpdateService.update_resident(resident, params, user)
        
        expect(ResidentMailer).to have_received(:welcome_new_user)
      end

      it 'links existing user if email already exists' do
        existing_user = create(:user, email: 'existing@example.com', name: 'Existing User')
        params = { email: 'existing@example.com' }
        initial_count = User.count

        expect {
          ResidentUpdateService.update_resident(resident, params, user)
        }.not_to change(User, :count)

        expect(resident.reload.user).to eq(existing_user)
      end

      it 'does not create user if email is blank' do
        params = { email: '' }
        initial_count = User.count
        
        expect {
          ResidentUpdateService.update_resident(resident, params, user)
        }.not_to change(User, :count)
      end
    end

    context 'when updating displayable data for resident with email' do
      let(:resident_with_email) { create(:resident, email: 'test@example.com', display_name: 'Original Name') }
      let(:params) { { display_name: 'Updated Name' } }

      it 'sends change notification email' do
        # Mock the email delivery
        allow(ResidentMailer).to receive(:data_change_notification).and_return(double(deliver_later: true))

        ResidentUpdateService.update_resident(resident_with_email, params, user)
        
        expect(ResidentMailer).to have_received(:data_change_notification).with(
          resident_with_email,
          hash_including('display_name' => hash_including(from: 'Original Name', to: 'Updated Name')),
          user
        )
      end

      it 'does not send email if resident has no email' do
        allow(ResidentMailer).to receive(:data_change_notification)
        ResidentUpdateService.update_resident(resident, params, user)
        expect(ResidentMailer).not_to have_received(:data_change_notification)
      end

      it 'does not send email if resident opted out' do
        resident_with_email.update(email_notifications_opted_out: true)
        allow(ResidentMailer).to receive(:data_change_notification)
        ResidentUpdateService.update_resident(resident_with_email, params, user)
        expect(ResidentMailer).not_to have_received(:data_change_notification)
      end

      it 'does not send email if no displayable fields changed' do
        params = { official_name: 'Different Official Name' } # Non-displayable field
        allow(ResidentMailer).to receive(:data_change_notification)
        ResidentUpdateService.update_resident(resident_with_email, params, user)
        expect(ResidentMailer).not_to have_received(:data_change_notification)
      end
    end

    context 'when both adding email and updating data' do
      let(:params) { { email: 'new@example.com', display_name: 'Updated Name' } }

      it 'creates user and sends welcome email, but not change notification' do
        allow(ResidentMailer).to receive(:welcome_new_user).and_return(double(deliver_later: true))
        allow(ResidentMailer).to receive(:data_change_notification)

        ResidentUpdateService.update_resident(resident, params, user)
        
        expect(ResidentMailer).to have_received(:welcome_new_user)
        expect(ResidentMailer).not_to have_received(:data_change_notification)
      end
    end
  end

  describe '.email_was_added?' do
    it 'returns true when email was added' do
      expect(ResidentUpdateService.send(:email_was_added?, nil, 'new@example.com')).to be true
      expect(ResidentUpdateService.send(:email_was_added?, '', 'new@example.com')).to be true
    end

    it 'returns false when email was not added' do
      expect(ResidentUpdateService.send(:email_was_added?, 'old@example.com', 'new@example.com')).to be false
      expect(ResidentUpdateService.send(:email_was_added?, 'old@example.com', '')).to be false
      expect(ResidentUpdateService.send(:email_was_added?, '', '')).to be false
    end
  end

  describe '.should_send_notification?' do
    let(:resident_with_email) { create(:resident, email: 'test@example.com') }
    let(:original_attributes) { resident_with_email.attributes.dup }

    it 'returns false if resident has no email' do
      resident = create(:resident, :without_email)
      expect(ResidentUpdateService.send(:should_send_notification?, resident, {})).to be false
    end

    it 'returns false if resident opted out' do
      resident_with_email.update(email_notifications_opted_out: true)
      expect(ResidentUpdateService.send(:should_send_notification?, resident_with_email, original_attributes)).to be false
    end

    it 'returns true if displayable fields changed' do
      original_attributes['display_name'] = 'Old Name'
      resident_with_email.display_name = 'New Name'
      expect(ResidentUpdateService.send(:should_send_notification?, resident_with_email, original_attributes)).to be true
    end

    it 'returns false if no displayable fields changed' do
      expect(ResidentUpdateService.send(:should_send_notification?, resident_with_email, original_attributes)).to be false
    end
  end
end