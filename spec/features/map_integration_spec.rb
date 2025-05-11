require 'rails_helper'

RSpec.feature "Map and Resident Editing Integration", type: :feature, js: true do
  xscenario "User edits a resident's display name via the map popup modal" do
    # Setup: create a house and resident
    house = FactoryBot.create(:house)
    resident = FactoryBot.create(:resident, house: house, display_name: "Old Name")

    visit root_path

    # Print browser console logs after page load
    if page.driver.browser.respond_to?(:logs)
      puts "\n[Browser console logs after page load:]"
      page.driver.browser.logs.get(:browser).each { |log| puts log.message }
    end

    # Center the map on the house polygon's first coordinate
    # These coordinates match the first point in the factory's rings, after conversion
    page.execute_script('window.map.setView([27.772074174, -82.728144652], 17);')

    # Wait for the map to load and at least one polygon to appear
    expect(page).to have_selector('.leaflet-interactive', wait: 10)

    # Click the first house polygon
    find('.leaflet-interactive', match: :first).click

    # Print browser console logs after clicking polygon
    if page.driver.browser.respond_to?(:logs)
      puts "\n[Browser console logs after clicking polygon:]"
      page.driver.browser.logs.get(:browser).each { |log| puts log.message }
    end

    # Wait for the popup to appear with the resident's name
    expect(page).to have_content("Old Name", wait: 5)

    # Click the Edit link in the popup
    within('.leaflet-popup-content') do
      click_link 'Edit'
    end

    # Wait for the modal to appear
    expect(page).to have_selector('form', wait: 5)

    # Fill in the display name and submit
    fill_in 'Display name', with: 'New Name'
    click_button 'Save'

    # Wait for the modal to disappear
    expect(page).not_to have_selector('form', wait: 5)

    # The popup should now show the updated name
    expect(page).to have_content('New Name')
    expect(page).not_to have_content('Old Name')

    # Try to edit again with invalid homepage
    within('.leaflet-popup-content') do
      click_link 'Edit'
    end
    expect(page).to have_selector('form', wait: 5)
    fill_in 'Homepage', with: 'invalid-homepage-url'
    click_button 'Save'
    # The form should still be visible and show a validation error
    expect(page).to have_selector('form', wait: 5)
    expect(page).to have_content('Homepage must start with https://')
  end
end
