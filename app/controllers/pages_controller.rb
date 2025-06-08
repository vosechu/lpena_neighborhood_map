class PagesController < ApplicationController
  # Allow public access to the map page for non-logged in users
  skip_before_action :authenticate_user!, only: [:map]

  def map
    # Show basic map functionality
    # Detailed resident data will only be available to authenticated users
  end
end
