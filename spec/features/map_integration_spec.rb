require 'rails_helper'

RSpec.feature 'Map core flows', type: :feature, js: true do
  include Warden::Test::Helpers

  scenario 'User edits existing resident then adds a new resident and sees updates immediately' do
    # Setup data
    user   = FactoryBot.create(:user)
    house  = FactoryBot.create(:house)
    resident = FactoryBot.create(:resident, house: house, display_name: 'Old Name')

    # Sign in and visit map
    login_as user, scope: :user
    visit root_path

    # Ensure map polygons load
    page.execute_script('window.map.setView([27.772074174, -82.728144652], 17);')
    expect(page).to have_selector('.leaflet-interactive', wait: 10)

    # --- Edit Existing Resident ---
    find('.leaflet-interactive', match: :first).click
    expect(page).to have_content('Old Name', wait: 5)

    # Open edit modal
    within('.leaflet-popup-content') do
      find('.edit-resident-btn').click
    end
    expect(page).to have_selector('#modal', wait: 10)

    # Change name + homepage (tests URL normalization)
    fill_in 'resident-name', with: 'New Name'
    fill_in 'resident-homepage', with: 'example.com'
    click_button 'Save Changes'

    # Wait for modal to close and popup to refresh
    expect(page).not_to have_selector('#modal[style*="block"]', wait: 10)
    expect(page).to have_content('New Name')
    resident.reload
    expect(resident.display_name).to eq('New Name')
    expect(resident.homepage).to eq('https://example.com')

    # --- Add New Resident ---
    within('.leaflet-popup-content') do
      find('.add-resident-btn').click
    end
    expect(page).to have_selector('#modal', wait: 10)

    fill_in 'resident-name', with: 'Newest Resident'
    fill_in 'resident-email', with: 'newresident@example.com'
    click_button 'Add Resident'

    # Wait for modal close and popup refresh
    expect(page).not_to have_selector('#modal[style*="block"]', wait: 10)
    expect(page).to have_content('Newest Resident')

    # Verify database update
    newest = house.residents.order(:created_at).last
    expect(newest.display_name).to eq('Newest Resident')
    expect(newest.email).to eq('newresident@example.com')
  end
end
