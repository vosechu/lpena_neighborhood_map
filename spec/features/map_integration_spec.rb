require 'rails_helper'

RSpec.feature 'Map core flows', type: :feature, js: true do
  include Warden::Test::Helpers

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
    expect(page).to have_selector('.leaflet-container', wait: 2)

    # Wait for houses to load asynchronously
    screenshot_on_timeout('houses_load_timeout', 'Waiting for houses to load on the map') do
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
    expect(page).to have_content('Old Name', wait: 2)

    # Open edit modal
    within('.leaflet-popup-content') do
      find('.edit-resident-btn').click
    end
    screenshot_on_timeout('edit_modal_timeout', 'Waiting for edit resident modal to appear after clicking edit button') do
      expect(page).to have_selector('[data-map-target="modal"]', wait: 2)
    end

    # Change name + homepage (tests URL normalization) and toggle "Hide all information"
    fill_in 'resident-name', with: 'New Name'
    fill_in 'resident-homepage', with: 'example.com'
    within('[data-map-target="modal"]') do
      check 'Hide all information', allow_label_click: true
    end
    click_button 'Save Changes'

    # Wait for modal to close and popup to refresh
    expect(page).not_to have_selector('[data-map-target="modal"][style*="block"]', wait: 2)
    expect(page).to have_content('New Name')
    resident.reload
    expect(resident.display_name).to eq('New Name')
    expect(resident.homepage).to eq('https://example.com')
    expect(resident.hidden).to be true

    # --- Add New Resident ---
    within('.leaflet-popup-content') do
      find('.add-resident-btn').click
    end
    screenshot_on_timeout('add_modal_timeout', 'Waiting for add resident modal to appear after clicking add button') do
      expect(page).to have_selector('[data-map-target="modal"]', wait: 2)
    end

    fill_in 'resident-name', with: 'Newest Resident'
    fill_in 'resident-email', with: 'newresident@example.com'
    click_button 'Add Resident'

    # Wait for modal close and popup refresh
    expect(page).not_to have_selector('[data-map-target="modal"][style*="block"]', wait: 2)
    expect(page).to have_content('Newest Resident')

    # Verify database update
    newest = house.residents.order(:created_at).last
    expect(newest.display_name).to eq('Newest Resident')
    expect(newest.email).to eq('newresident@example.com')
  end
end
