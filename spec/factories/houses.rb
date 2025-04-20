FactoryBot.define do
  factory :house do
    sequence(:pcpa_uid) { |n| "PCPA#{n}" }
    street_number { 6573 }
    street_name { '1ST AVE N' }
    city { 'St Petersburg' }
    state { 'FL' }
    zip { '33710' }
    latitude { 27.772074174 }
    longitude { -82.728144652 }
    boundary_geometry do
      {
        'rings' => [
          [[-82.728144652, 27.772074174], [-82.728144652, 27.772074174]]
        ]
      }
    end

    trait :minimal do
      # For when we want to set most attributes manually
      pcpa_uid { nil }
      street_number { nil }
      street_name { nil }
      city { nil }
      state { nil }
      zip { nil }
      latitude { nil }
      longitude { nil }
      boundary_geometry { nil }
    end
  end
end
