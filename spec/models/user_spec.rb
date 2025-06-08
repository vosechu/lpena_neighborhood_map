require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'requires an email' do
      user = User.new(name: 'Test User')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires a name' do
      user = User.new(email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'requires a unique email' do
      User.create!(name: 'First User', email: 'test@example.com', password: 'password123')
      user = User.new(name: 'Second User', email: 'test@example.com', password: 'password123')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'validates role inclusion' do
      user = User.new(name: 'Test User', email: 'test@example.com', password: 'password123', role: 'invalid')
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include('is not included in the list')
    end
  end

  describe 'role methods' do
    let(:admin_user) { User.new(role: 'admin') }
    let(:regular_user) { User.new(role: 'user') }

    it 'identifies admin users' do
      expect(admin_user.admin?).to be true
      expect(regular_user.admin?).to be false
    end

    it 'identifies regular users' do
      expect(regular_user.user?).to be true
      expect(admin_user.user?).to be false
    end
  end

  describe 'associations' do
    it 'can have a resident' do
      user = User.new
      expect(user).to respond_to(:resident)
    end

    it 'can have a house through resident' do
      user = User.new
      expect(user).to respond_to(:house)
    end
  end

  describe 'Devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'does not include registerable (closed site)' do
      expect(User.devise_modules).not_to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes trackable' do
      expect(User.devise_modules).to include(:trackable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end
end
