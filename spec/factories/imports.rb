FactoryBot.define do
  factory :import do
    user
    gallery
    provider { "flickr" }
    status { "pending" }
  end
end
