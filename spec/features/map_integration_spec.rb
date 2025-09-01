require 'rails_helper'

RSpec.feature 'Map core flows', type: :feature, js: true do
  include Warden::Test::Helpers

  scenario 'Login page loads correctly' do
    visit new_user_session_path

    expect(page).to have_title(/Lpena Neighborhood Map/)
    expect(page).to have_selector('form')
    expect(page).to have_field('Email')
    expect(page).to have_field('Password')
    expect(page).to have_button('Sign In')
  end

  scenario 'Resident owner edits their info, toggles visibility, and adds a new resident—all in one flow' do
    # Setup data
    user   = FactoryBot.create(:user)
    house  = FactoryBot.create(:house)
    resident = FactoryBot.create(
      :resident,
      house: house,
      user: user,
      display_name: 'Old Name',
      phone: '727-555-9999',
      hide_phone: false,
      first_seen_at: 2.months.ago,  # Avoid triggering recent changes icon
      hidden: false  # Ensure resident is visible
    )

    # Sign in and visit map
    login_as user, scope: :user
    visit root_path

    # Wait for map to be initialized and houses to load
    screenshot_on_failure('container_load_timeout', 'Waiting for map container to load') do
      expect(page).to have_selector('.leaflet-container', wait: 10)
    end

    # Check if assets are loaded
    expect(page).to have_selector('body', wait: 5)

    # Wait for houses to load asynchronously
    screenshot_on_failure('houses_load_timeout', 'Waiting for houses to load on the map') do
      Timeout.timeout(3) do
        loop do
          break if page.evaluate_script('window.map && window.map._layers && Object.values(window.map._layers).filter(l => l instanceof L.Polygon).length > 0')
          sleep 0.1
        end
      end
    end

    page.execute_script('window.map.setView([27.772074174, -82.728144652], 17);')

    # --- Edit Existing Resident ---
    find('.leaflet-interactive', match: :first).click
    expect(page).to have_content('Old Name', wait: 5)

    # Open edit modal
    within('.leaflet-popup-content') do
      find('.edit-resident-btn').click
    end
    screenshot_on_failure('edit_modal_timeout', 'Waiting for edit resident modal to appear after clicking edit button') do
      expect(page).to have_selector('[data-map-target="modal"]', wait: 5)
    end

    # Change name + homepage (tests URL normalization) and toggle "Hide all information"
    fill_in 'resident-name', with: 'New Name'
    fill_in 'resident-homepage', with: 'example.com'

    screenshot_on_failure('checkbox_click_timeout', 'Clicking hide all information checkbox') do
      # Wait for the checkbox to be present and visible
      expect(page).to have_selector('#resident-hide-all', wait: 5)

      # Use JavaScript to click the checkbox to avoid element interception
      page.execute_script("document.getElementById('resident-hide-all').click()")
    end

    # Use JavaScript to click the Save button to avoid element interception
    page.execute_script("document.querySelector('.save-resident-btn').click()")

    # Wait for modal to close and popup to refresh
    expect(page).not_to have_selector('[data-map-target="modal"][style*="block"]', wait: 5)
    expect(page).to have_content('New Name')
    resident.reload
    expect(resident.display_name).to eq('New Name')
    expect(resident.homepage).to eq('https://example.com')
    expect(resident.hidden).to be true

    # --- Add New Resident ---
    # Re-find the popup content to avoid stale element reference
    # Wait for popup to be stable after the edit operation
    expect(page).to have_selector('.leaflet-popup-content .add-resident-btn', wait: 5)
    # Use JavaScript to avoid stale element reference
    page.execute_script("document.querySelector('.add-resident-btn').click()")

    screenshot_on_failure('add_modal_timeout', 'Waiting for add resident modal to appear after clicking add button') do
      expect(page).to have_selector('[data-map-target="modal"]', wait: 5)
    end

    fill_in 'resident-name', with: 'Newest Resident'
    fill_in 'resident-email', with: 'newresident@example.com'
    click_button 'Add Resident'

    # Wait for modal close and popup refresh
    expect(page).not_to have_selector('[data-map-target="modal"][style*="block"]', wait: 5)
    expect(page).to have_content('Newest Resident')

    # Verify database update
    newest = house.residents.order(:created_at).last
    expect(newest.display_name).to eq('Newest Resident')
    expect(newest.email).to eq('newresident@example.com')

    # --- Test New Residents Checkbox Feature ---
    # First update the newest resident to have a recent first_seen_at to make it show up in new residents
    newest.update!(first_seen_at: 10.days.ago)

    # Find and check the new residents checkbox
    checkbox = find('input[data-map-target="newResidentsToggle"]')
    expect(checkbox).not_to be_checked
    
    # Initially, the list should be hidden
    expect(page).to have_selector('[data-map-target="newResidentsList"].hidden', visible: false)
    
    # Click the checkbox to expand the list using JavaScript (avoid element interception)
    page.execute_script("document.querySelector('input[data-map-target=\"newResidentsToggle\"]').click()")
    
    # Wait for list to appear and be populated
    expect(page).not_to have_selector('[data-map-target="newResidentsList"].hidden', wait: 5)
    
    # Check that the list contains the new resident
    within('[data-map-target="newResidentsList"]') do
      expect(page).to have_content(house.street_number.to_s + ' ' + house.street_name)
      expect(page).to have_content('Newest Resident')
    end
    
    # Uncheck the checkbox to hide the list using JavaScript
    page.execute_script("document.querySelector('input[data-map-target=\"newResidentsToggle\"]').click()")
    
    # List should be hidden again
    expect(page).to have_selector('[data-map-target="newResidentsList"].hidden', visible: false)
  end
end
