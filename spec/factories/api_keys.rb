FactoryBot.define do
  factory :api_key do
    association :user, factory: :user, role: :admin
    name { Faker::App.name }
    scope { "admin" }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end

    trait :read_only do
      scope { "read_only" }
    end
  end
end
