# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the user here
    user ||= User.new # guest user (not logged in)

    if user.admin?
      # Admin can manage everything
      can :manage, :all
      # Rails Admin access (commented out for future merge)
      # can :access, :rails_admin
      # can :read, :dashboard
    elsif user.user?
      # Regular users can read and manage ALL residents and houses
      can :read, House
      can :read, Resident
      can :manage, Resident
      can :read, House
      can :manage, House
      
      # Users can only read and update their own user record
      can :read, User, id: user.id
      can :update, User, id: user.id
    else
      # Guest users (not logged in) have no permissions
      # They should be redirected to login
    end
  end
end
