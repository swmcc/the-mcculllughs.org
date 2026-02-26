FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    password { "password12345" }
    role { :member }

    trait :admin do
      role { :admin }
    end
  end
end
