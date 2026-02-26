require 'rails_helper'

RSpec.describe PhotoImporter do
  let(:user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }
  let(:import) { create(:import, user: user, gallery: gallery, provider: "flickr") }

  let(:provider) { double("Provider") }

  describe "#generate_filename security" do
    it "sanitizes file extensions to prevent path traversal" do
      photo_data = {
        "id" => "12345",
        "originalformat" => "../../etc/passwd"
      }

      importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
      filename = importer.send(:generate_filename)

      expect(filename).not_to include("..")
      expect(filename).not_to include("/")
      expect(filename).to eq("flickr_12345.jpg") # Falls back to jpg for invalid extension
    end

    it "sanitizes photo IDs to prevent injection" do
      photo_data = {
        "id" => "12345; rm -rf /",
        "originalformat" => "jpg"
      }

      importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
      filename = importer.send(:generate_filename)

      expect(filename).not_to include(";")
      expect(filename).not_to include(" ")
      expect(filename).to eq("flickr_12345rm-rf.jpg")
    end

    it "only allows known safe extensions" do
      safe_extensions = %w[jpg jpeg png gif webp heic heif mp4 mov avi webm]

      safe_extensions.each do |ext|
        photo_data = { "id" => "123", "originalformat" => ext }
        importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
        filename = importer.send(:generate_filename)

        expect(filename).to end_with(".#{ext}")
      end
    end

    it "falls back to jpg for unknown extensions" do
      dangerous_extensions = %w[php exe sh bat cmd ps1 html js]

      dangerous_extensions.each do |ext|
        photo_data = { "id" => "123", "originalformat" => ext }
        importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
        filename = importer.send(:generate_filename)

        expect(filename).to end_with(".jpg")
        expect(filename).not_to include(ext)
      end
    end

    it "handles nil originalformat" do
      photo_data = { "id" => "123", "originalformat" => nil }
      importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
      filename = importer.send(:generate_filename)

      expect(filename).to eq("flickr_123.jpg")
    end

    it "handles empty originalformat" do
      photo_data = { "id" => "123", "originalformat" => "" }
      importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
      filename = importer.send(:generate_filename)

      expect(filename).to eq("flickr_123.jpg")
    end
  end

  describe "#detect_content_type" do
    it "maps known extensions to correct content types" do
      mappings = {
        "jpg" => "image/jpeg",
        "jpeg" => "image/jpeg",
        "png" => "image/png",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "mp4" => "video/mp4",
        "mov" => "video/quicktime"
      }

      mappings.each do |ext, expected_type|
        photo_data = { "id" => "123", "originalformat" => ext }
        importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
        content_type = importer.send(:detect_content_type, nil)

        expect(content_type).to eq(expected_type)
      end
    end

    it "defaults to image/jpeg for unknown formats" do
      photo_data = { "id" => "123", "originalformat" => "unknown" }
      importer = described_class.new(import: import, photo_data: photo_data, provider: provider)
      content_type = importer.send(:detect_content_type, nil)

      expect(content_type).to eq("image/jpeg")
    end
  end
end
