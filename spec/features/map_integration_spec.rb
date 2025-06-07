require 'rails_helper'

RSpec.feature "Map and Resident Editing Integration", type: :feature, js: true do
  scenario "User edits a resident's homepage without protocol and sees it normalized" do
    # Setup: create a house and resident
    house = FactoryBot.create(:house)
    resident = FactoryBot.create(:resident, house: house, display_name: "Old Name", homepage: nil)

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

    # Fill in the homepage without protocol and submit
    fill_in 'Homepage', with: 'chuckvose.com'
    click_button 'Save'

    # Wait for the modal to disappear
    expect(page).not_to have_selector('form', wait: 5)

    # The popup should now show the normalized homepage when reopened
    # Close any existing popup by pressing Escape (handled by JS)
    page.send_keys :escape

    # Click polygon again to reopen popup
    find('.leaflet-interactive', match: :first).click

    expect(page).to have_content('https://chuckvose.com', wait: 5)

    # Ensure there are no validation errors in the server log
  end
end
