require 'rails_helper'

RSpec.describe AdminNotificationMailer, type: :mailer do
  describe '#data_conflict_notification' do
    let(:conflicts) do
      [
        {
          type: 'address_change',
          house_id: 1,
          pcpa_uid: 'TEST123',
          old_address: '123 Old St, Old City, FL 12345',
          new_address: '456 New St, New City, FL 67890',
          resolution: 'auto_accept_latest',
          timestamp: Time.current
        },
        {
          type: 'ownership_change',
          house_id: 2,
          pcpa_uid: 'TEST456',
          address: '789 Test Ave, Test City, FL 11111',
          old_owners: ['John Doe'],
          new_owners: ['Jane Smith'],
          resolution: 'auto_accept_latest',
          timestamp: Time.current
        }
      ]
    end

    let(:summary) do
      {
        total_conflicts: 2,
        resolved_automatically: 2,
        requires_manual_review: 0,
        conflicts_by_type: {
          'address_change' => 1,
          'ownership_change' => 1
        }
      }
    end

    let(:mail) { described_class.data_conflict_notification(conflicts, summary, 45.67) }

    it 'renders the subject' do
      expect(mail.subject).to eq('Data Conflicts Detected - 2 conflicts found')
    end

    it 'sends to the admin email' do
      expect(mail.to).to eq(['vosechu@gmail.com'])
    end

    it 'includes conflict details in the body' do
      expect(mail.body.encoded).to include('address_change')
      expect(mail.body.encoded).to include('ownership_change')
      expect(mail.body.encoded).to include('123 Old St')
      expect(mail.body.encoded).to include('John Doe')
    end

    it 'includes summary information' do
      expect(mail.body.encoded).to include('Total Conflicts: 2')
      expect(mail.body.encoded).to include('Resolved Automatically: 2')
    end
  end

  describe '#job_failure_notification' do
    let(:error_message) { 'StandardError: Connection failed' }
    let(:mail) { described_class.job_failure_notification(error_message, 30.5) }

    it 'renders the subject' do
      expect(mail.subject).to eq('Property Data Import Job Failed')
    end

    it 'sends to the admin email' do
      expect(mail.to).to eq(['vosechu@gmail.com'])
    end

    it 'includes error details in the body' do
      expect(mail.body.encoded).to include(error_message)
      expect(mail.body.encoded).to include('30.5 seconds')
    end

    it 'includes action items' do
      expect(mail.body.encoded).to include('Check the application logs')
      expect(mail.body.encoded).to include('Verify the PCPA GIS service')
    end
  end
end