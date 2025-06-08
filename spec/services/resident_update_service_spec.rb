require 'rails_helper'

RSpec.describe ResidentUpdateService, type: :service do
  describe '.update_resident' do
    context 'when updating basic information' do
      it 'updates the resident successfully' do
        resident = create(:resident, :without_email)
        params = { display_name: 'Updated Name' }

        expect(ResidentUpdateService.update_resident(resident, params)).to be true
        expect(resident.reload.display_name).to eq('Updated Name')
      end

      it 'returns false if update fails' do
        resident = create(:resident, :without_email)
        params = { display_name: 'Updated Name' }

        allow(resident).to receive(:update).and_return(false)
        expect(ResidentUpdateService.update_resident(resident, params)).to be false
      end
    end

    context 'when adding an email to a resident' do
      context 'with a new email address' do
        it 'creates a new user for the resident' do
          User.destroy_all # Clear users for this test

          resident = create(:resident, :without_email)
          params = { email: 'new-unique@example.com' }

          initial_user_count = User.count

          result = ResidentUpdateService.update_resident(resident, params)

          expect(result).to be true
          expect(User.count).to eq(initial_user_count + 1)

          new_user = User.find_by(email: 'new-unique@example.com')
          expect(new_user).to be_present
          expect(new_user.name).to eq(resident.display_name)
          expect(resident.reload.user).to eq(new_user)
        end

        it 'sends a welcome email' do
          resident = create(:resident, :without_email)
          params = { email: 'new-unique2@example.com' }

          allow(ResidentMailer).to receive(:welcome_new_user).and_return(double(deliver_later: true))

          ResidentUpdateService.update_resident(resident, params)

          expect(ResidentMailer).to have_received(:welcome_new_user)
        end
      end

      context 'when user already exists with that email' do
        it 'links existing user if email already exists' do
          User.destroy_all # Clear users for this test

          existing_user = create(:user, email: 'existing-unique@example.com', name: 'Existing User')
          resident = create(:resident, :without_email)
          params = { email: 'existing-unique@example.com' }

          initial_user_count = User.count

          result = ResidentUpdateService.update_resident(resident, params)

          expect(result).to be true
          expect(User.count).to eq(initial_user_count)
          expect(resident.reload.user).to eq(existing_user)
        end
      end

      context 'when email is blank' do
        it 'does not create user if email is blank' do
          User.destroy_all # Clear users for this test

          resident = create(:resident, :without_email)
          params = { email: '' }

          initial_user_count = User.count

          result = ResidentUpdateService.update_resident(resident, params)

          expect(result).to be true
          expect(User.count).to eq(initial_user_count)
          expect(resident.reload.user).to be_nil
        end
      end
    end

    context 'when updating displayable data for resident with email' do
      it 'sends change notification email including email changes' do
        resident_with_email = create(:resident, email: 'test-resident@example.com', display_name: 'Original Name')
        params = { display_name: 'Updated Name', email: 'new-email@example.com' }

        allow(ResidentMailer).to receive(:data_change_notification).and_return(double(deliver_later: true))

        ResidentUpdateService.update_resident(resident_with_email, params)

        expect(ResidentMailer).to have_received(:data_change_notification).with(
          resident_with_email,
          hash_including(
            'display_name' => hash_including(from: 'Original Name', to: 'Updated Name'),
            'email' => hash_including(from: 'test-resident@example.com', to: 'new-email@example.com')
          )
        )
      end

      it 'does not send email if resident has no email' do
        resident_no_email = create(:resident, :without_email)
        params = { display_name: 'Updated Name' }

        allow(ResidentMailer).to receive(:data_change_notification)

        ResidentUpdateService.update_resident(resident_no_email, params)

        expect(ResidentMailer).not_to have_received(:data_change_notification)
      end

      it 'does not send email if resident is hidden' do
        resident_with_email = create(:resident, email: 'test-resident2@example.com', display_name: 'Original Name', hidden: true)
        params = { display_name: 'Updated Name' }

        allow(ResidentMailer).to receive(:data_change_notification)

        ResidentUpdateService.update_resident(resident_with_email, params)

        expect(ResidentMailer).not_to have_received(:data_change_notification)
      end

      it 'does not send email if no displayable fields changed' do
        resident_with_email = create(:resident, email: 'test-resident3@example.com', display_name: 'Original Name')
        params = { official_name: 'Different Official Name' } # Non-displayable field

        allow(ResidentMailer).to receive(:data_change_notification)

        ResidentUpdateService.update_resident(resident_with_email, params)

        expect(ResidentMailer).not_to have_received(:data_change_notification)
      end
    end

    context 'when both adding email and updating data' do
      it 'creates user, sends welcome email, and also sends change notification' do
        resident = create(:resident, :without_email, display_name: 'Original Name')
        params = { email: 'new-both@example.com', display_name: 'Updated Name' }

        allow(ResidentMailer).to receive(:welcome_new_user).and_return(double(deliver_later: true))
        allow(ResidentMailer).to receive(:data_change_notification).and_return(double(deliver_later: true))

        ResidentUpdateService.update_resident(resident, params)

        expect(ResidentMailer).to have_received(:welcome_new_user)
        expect(ResidentMailer).to have_received(:data_change_notification)
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
    it 'returns false if resident has no email' do
      resident = create(:resident, :without_email)
      expect(ResidentUpdateService.send(:should_send_notification?, resident, {})).to be false
    end

    it 'returns false if resident is hidden' do
      resident_with_email = create(:resident, email: 'test-notification@example.com', hidden: true)
      original_attributes = resident_with_email.attributes.dup

      expect(ResidentUpdateService.send(:should_send_notification?, resident_with_email, original_attributes)).to be false
    end

    it 'returns true if displayable fields changed including email' do
      resident_with_email = create(:resident, email: 'test-notification2@example.com')
      original_attributes = resident_with_email.attributes.dup

      original_attributes['display_name'] = 'Old Name'
      resident_with_email.display_name = 'New Name'
      expect(ResidentUpdateService.send(:should_send_notification?, resident_with_email, original_attributes)).to be true

      # Test email changes too
      original_attributes['email'] = 'old@example.com'
      resident_with_email.email = 'new@example.com'
      expect(ResidentUpdateService.send(:should_send_notification?, resident_with_email, original_attributes)).to be true
    end

    it 'returns false if no displayable fields changed' do
      resident_with_email = create(:resident, email: 'test-notification3@example.com')
      original_attributes = resident_with_email.attributes.dup

      expect(ResidentUpdateService.send(:should_send_notification?, resident_with_email, original_attributes)).to be false
    end
  end
end
