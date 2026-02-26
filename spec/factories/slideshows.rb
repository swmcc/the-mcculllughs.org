FactoryBot.define do
  factory :slideshow do
    user
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    interval { 5 }
  end
end
