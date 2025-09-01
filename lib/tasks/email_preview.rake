desc 'Preview all emails using Letter Opener'
task email_preview: :environment do
  puts 'Generating email previews...'

  # Use existing resident/user for realistic previews
  existing_resident = Resident.joins(:user).first
  existing_house = existing_resident&.house || House.first

  if existing_resident && existing_resident.user && existing_house
    puts 'Using existing data for previews...'

    # Create unsaved mock objects
    old_resident = Resident.new(official_name: 'John Doe', house: existing_house)
    new_resident = Resident.new(official_name: 'Jane Smith', house: existing_house)
    inviter_house = House.new(street_number: '456', street_name: 'Elm Street')
    inviter = Resident.new(display_name: 'Bob Neighbor', house: inviter_house)

    # 1. House transition notification
    changes = { residents_removed: [ old_resident ], residents_added: [ new_resident ] }
    ResidentMailer.house_transition_notification(existing_house, changes).deliver_now
    puts '✓ House transition email sent'

    # 2. Welcome email with inviter
    ResidentMailer.welcome_new_user(existing_resident, existing_resident.user, inviter).deliver_now
    puts '✓ Welcome email with inviter sent'

    # 3. Welcome email without inviter
    ResidentMailer.welcome_new_user(existing_resident, existing_resident.user, nil).deliver_now
    puts '✓ Welcome email without inviter sent'

    # 4. Data change notification
    changes = { 'display_name' => { from: 'Old Name', to: 'New Name' } }
    ResidentMailer.data_change_notification(existing_resident, changes).deliver_now
    puts '✓ Data change notification sent'

    puts "\nAll emails sent via Letter Opener! Check your browser."
  else
    puts 'Error: Need existing resident with user and house in database'
    puts "Available residents: #{Resident.count}"
    puts "Available users: #{User.count}"
    puts "Available houses: #{House.count}"
  end
end
