# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # AIDEV-NOTE: See @authentication.mdc
  def initialize(user)
    # Define abilities for the user here
    user ||= User.new # guest user (not logged in)

    if user.admin?
      # Admin can manage everything
      can :manage, :all
      can :access, :rails_admin
      can :read, :dashboard
    elsif user.user?
      # Regular users can read all houses and residents, but manage only their own records
      can :read, House
      can :read, Resident

      # Manage permissions limited to the resident linked to their user record
      can :manage, Resident, user_id: user.id

      # Allow managing the house they belong to (through their resident record)
      can :manage, House, id: House.joins(residents: :user).where(residents: { user_id: user.id }).select(:id)

      # Users can only read and update their own user record
      can :read, User, id: user.id
      can :update, User, id: user.id
    else
      # Guest users (not logged in) have no permissions
      # They should be redirected to login
    end
  end
end
