FactoryBot.define do
  factory :upload do
    title { Faker::Lorem.sentence(word_count: 3) }
    caption { Faker::Lorem.paragraph }
    user
    gallery

    after(:build) do |upload|
      upload.file.attach(
        io: StringIO.new("fake image data"),
        filename: "test_image.jpg",
        content_type: "image/jpeg"
      )
    end
  end
end
