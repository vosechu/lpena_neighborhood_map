# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the user here
    user ||= User.new # guest user (not logged in)

    if user.admin?
      # Admin can manage everything
      can :manage, :all
      can :access, :rails_admin
      can :read, :dashboard
    elsif user.user?
      # Regular users can read and manage their own data
      can :read, House, users: { id: user.id }
      can :read, Resident, user_id: user.id
      can :manage, Resident, user_id: user.id
      can :read, User, id: user.id
      can :update, User, id: user.id
    else
      # Guest users (not logged in) have no permissions
      # They should be redirected to login
    end
  end
end
