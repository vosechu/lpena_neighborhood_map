FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "User #{n}" }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { 'user' }

    trait :admin do
      role { 'admin' }
      sequence(:email) { |n| "admin#{n}@example.com" }
      sequence(:name) { |n| "Admin #{n}" }
    end

    factory :admin_user, traits: [ :admin ]
  end
end
