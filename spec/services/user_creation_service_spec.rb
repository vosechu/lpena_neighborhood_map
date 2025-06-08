require 'rails_helper'

RSpec.describe UserCreationService, type: :service do
  describe '.create_user' do
    it 'creates a user with default role' do
      user = UserCreationService.create_user(
        email: 'test@example.com',
        name: 'Test User'
      )

      expect(user).to be_persisted
      expect(user.email).to eq('test@example.com')
      expect(user.name).to eq('Test User')
      expect(user.role).to eq('user')
      expect(user.encrypted_password).to be_present
    end

    it 'creates an admin user when specified' do
      user = UserCreationService.create_user(
        email: 'admin@example.com',
        name: 'Admin User',
        role: 'admin'
      )

      expect(user).to be_persisted
      expect(user.role).to eq('admin')
      expect(user.admin?).to be true
    end

    it 'raises error for invalid data' do
      expect {
        UserCreationService.create_user(
          email: 'invalid-email',
          name: ''
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '.generate_initial_login_token' do
    let(:user) { create(:user) }

    it 'generates a password reset token' do
      token = UserCreationService.generate_initial_login_token(user)

      expect(token).to be_present
      user.reload
      expect(user.reset_password_token).to be_present
      expect(user.reset_password_sent_at).to be_present
    end
  end
end
