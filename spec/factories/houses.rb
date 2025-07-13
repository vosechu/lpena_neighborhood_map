FactoryBot.define do
  factory :house do
    sequence(:pcpa_uid) { |n| "PCPA#{n}" }
    sequence(:street_number) { |n| 6573 + n }
    sequence(:street_name) { |n| "1st Ave N" }
    city { 'St Petersburg' }
    state { 'FL' }
    zip { '33710' }
    latitude { 27.772074174 }
    longitude { -82.728144652 }
    boundary_geometry do
      {
        'rings' => [
          [
            [ -9209240.757138861, 3220294.471787363 ],
            [ -9209240.570790969, 3220242.56455914  ],
            [ -9209269.830229428, 3220242.456222947 ],
            [ -9209270.01668635,  3220294.363220923 ],
            [ -9209240.757138861, 3220294.471787363 ]
          ]
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
