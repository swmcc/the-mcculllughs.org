FactoryBot.define do
  factory :import do
    user
    gallery
    provider { "flickr" }
    status { "pending" }
    external_album_id { SecureRandom.hex(8) }
  end
end
