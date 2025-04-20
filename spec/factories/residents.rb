FactoryBot.define do
  factory :resident do
    association :house
    sequence(:official_name) { |n| "Resident #{n}" }
    first_seen_at { Time.current }
    last_import_at { Time.current }

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
      share_display_name { true }
      share_email { true }
      share_phone { true }
      share_birthdate { true }
    end

    trait :moved_out do
      last_seen_at { Time.current }
    end

    trait :welcomed do
      welcomed_on { 1.month.ago }
    end

    trait :former do
      moved_out_at { Time.current }
    end
  end
end
