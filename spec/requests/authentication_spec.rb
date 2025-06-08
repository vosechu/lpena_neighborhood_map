require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  describe 'accessing protected resources' do
    context 'when not logged in' do
      it 'redirects to login page for protected API endpoints' do
        get '/api/houses'
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to login page for map page' do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when logged in as regular user' do
      let(:user) { create(:user) }

      before do
        sign_in user
      end

      it 'allows access to API endpoints' do
        get '/api/houses'
        expect(response).to have_http_status(200)
      end

      it 'allows access to map page' do
        get root_path
        expect(response).to have_http_status(200)
      end

      it 'denies access to admin interface' do
        expect { get rails_admin_path }.to raise_error(CanCan::AccessDenied)
      end
    end

    context 'when logged in as admin' do
      let(:admin) { create(:admin_user) }

      before do
        sign_in admin
      end

      it 'allows access to API endpoints' do
        get '/api/houses'
        expect(response).to have_http_status(200)
      end

      it 'allows access to map page' do
        get root_path
        expect(response).to have_http_status(200)
      end

      it 'has admin permissions' do
        expect(admin.admin?).to be true
        ability = Ability.new(admin)
        expect(ability.can?(:manage, :all)).to be true
        expect(ability.can?(:access, :rails_admin)).to be true
      end
    end
  end

  describe 'user registration' do
    it 'registration routes are disabled' do
      expect(Rails.application.routes.url_helpers).not_to respond_to(:user_registration_path)
    end

    it 'registration links are not available' do
      get new_user_session_path
      expect(response.body).not_to include('Sign up')
    end
  end

  describe 'password reset' do
    let(:user) { create(:user) }

    it 'allows password reset request' do
      post user_password_path, params: { user: { email: user.email } }
      expect(response).to redirect_to(new_user_session_path)
      
      # Check that reset token was set
      user.reload
      expect(user.reset_password_token).to be_present
    end
  end

  describe 'authorization rules' do
    let(:user) { create(:user) }
    let(:admin) { create(:admin_user) }
    let(:other_user) { create(:user) }

    context 'regular user abilities' do
      let(:ability) { Ability.new(user) }

      it 'can manage all residents' do
        expect(ability.can?(:manage, Resident)).to be true
      end

      it 'can read all houses' do
        expect(ability.can?(:read, House)).to be true
      end

      it 'can only manage own user record' do
        expect(ability.can?(:read, user)).to be true
        expect(ability.can?(:update, user)).to be true
        expect(ability.can?(:read, other_user)).to be false
        expect(ability.can?(:update, other_user)).to be false
      end
    end

    context 'admin abilities' do
      let(:ability) { Ability.new(admin) }

      it 'can manage everything' do
        expect(ability.can?(:manage, :all)).to be true
      end
    end
  end
end