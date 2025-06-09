require 'rails_helper'

RSpec.feature "Map and Resident Editing Integration", type: :feature, js: true do
  include Warden::Test::Helpers
  scenario "User edits a resident's display name and homepage with URL normalization via the map popup modal" do
    # Setup: create a user, house and resident
    user = FactoryBot.create(:user)
    house = FactoryBot.create(:house)
    resident = FactoryBot.create(:resident, house: house, display_name: "Old Name", user: user)

    # Sign in the user
    login_as user, scope: :user
    visit root_path

    # Center the map on the house polygon's first coordinate
    # These coordinates match the first point in the factory's rings, after conversion
    page.execute_script('window.map.setView([27.772074174, -82.728144652], 17);')

    # Wait for the map to load and at least one polygon to appear
    expect(page).to have_selector('.leaflet-interactive', wait: 10)

    # Click the first house polygon
    find('.leaflet-interactive', match: :first).click

    # Wait for the popup to appear with the resident's name
    expect(page).to have_content("Old Name", wait: 5)

    # Click the Edit button in the popup
    within('.leaflet-popup-content') do
      find('.edit-resident-btn').click
    end

    # Wait for the modal to appear
    expect(page).to have_selector('#modal', wait: 5)

    # Fill in the display name and homepage (testing URL normalization)
    fill_in 'resident-name', with: 'New Name'
    fill_in 'resident-homepage', with: 'example.com'  # Should be normalized to https://example.com
    click_button 'Save Changes'

    # Give time for the API call to complete
    sleep(1)

    # Wait for the modal to disappear
    expect(page).not_to have_selector('#modal[style*="block"]', wait: 5)

    # The popup should now show the updated name
    expect(page).to have_content('New Name')
    expect(page).not_to have_content('Old Name')

    # Verify the resident was actually updated in the database
    resident.reload
    expect(resident.display_name).to eq('New Name')
    expect(resident.homepage).to eq('https://example.com') # URL should be normalized
  end
end
