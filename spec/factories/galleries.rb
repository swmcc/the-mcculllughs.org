FactoryBot.define do
  factory :gallery do
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    user
  end
end
