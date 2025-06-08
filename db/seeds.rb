# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create an admin user for development and testing
if Rails.env.development?
  admin_user = User.find_or_create_by(email: 'admin@example.com') do |user|
    user.name = 'Admin User'
    user.password = 'password123'
    user.password_confirmation = 'password123'
    user.role = 'admin'
  end

  puts "Admin user created: #{admin_user.email}" if admin_user.persisted?

  # Create a regular test user
  test_user = User.find_or_create_by(email: 'user@example.com') do |user|
    user.name = 'Test User'
    user.password = 'password123'
    user.password_confirmation = 'password123'
    user.role = 'user'
  end

  puts "Test user created: #{test_user.email}" if test_user.persisted?
end
