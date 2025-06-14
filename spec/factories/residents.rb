FactoryBot.define do
  factory :resident do
    association :house
    sequence(:official_name) { |n| "Resident #{n}" }
    first_seen_at { Time.current }
    last_import_at { Time.current }
    display_name { "Test User" }
    phone { "555-1234" }
    sequence(:email) { |n| "user#{n}@example.com" }
    homepage { "https://example.com" }
    skills { "Programming, Testing" }
    comments { "Test comment" }
    email_notifications_opted_out { false }

    trait :minimal do
      # For when we want to set most attributes manually
      initialize_with { new(attributes) }
    end

    trait :with_contact_info do
      email { 'john@example.com' }
      phone { '727-555-0123' }
      birthdate { 30.years.ago }
    end

    trait :sharing_all do
      hide_display_name { false }
      hide_email { false }
      hide_phone { false }
      hide_birthdate { false }
    end

    trait :hiding_all do
      hide_display_name { true }
      hide_email { true }
      hide_phone { true }
      hide_birthdate { true }
    end

    trait :moved_out do
      moved_out_at { Time.current }
    end

    trait :welcomed do
      welcomed_on { 1.month.ago }
    end

    trait :former do
      moved_out_at { Time.current }
    end

    trait :with_user do
      association :user
    end

    trait :opted_out_of_notifications do
      email_notifications_opted_out { true }
    end

    trait :opted_out_of_emails do
      email_notifications_opted_out { true }
    end

    trait :without_email do
      email { nil }
    end
  end
end
