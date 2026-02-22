require 'rails_helper'

RSpec.describe Gallery, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:cover_upload).class_name("Upload").optional }
    it { is_expected.to have_many(:uploads).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:user) }
  end

  describe "scopes" do
    describe ".recent" do
      it "returns galleries ordered by created_at desc" do
        user = create(:user)
        old_gallery = create(:gallery, user: user, created_at: 2.days.ago)
        new_gallery = create(:gallery, user: user, created_at: 1.day.ago)

        expect(Gallery.recent).to eq([ new_gallery, old_gallery ])
      end
    end
  end

  describe "cover photo validation" do
    it "allows cover_upload from the same gallery" do
      gallery = create(:gallery)
      upload = create(:upload, gallery: gallery)
      gallery.cover_upload = upload

      expect(gallery).to be_valid
    end

    it "rejects cover_upload from a different gallery" do
      gallery = create(:gallery)
      other_gallery = create(:gallery)
      upload = create(:upload, gallery: other_gallery)
      gallery.cover_upload = upload

      expect(gallery).not_to be_valid
      expect(gallery.errors[:cover_upload]).to include("must belong to this gallery")
    end
  end

  describe "#cover_photo" do
    it "returns the cover_upload when set" do
      gallery = create(:gallery)
      upload1 = create(:upload, gallery: gallery)
      upload2 = create(:upload, gallery: gallery)
      gallery.update!(cover_upload: upload2)

      expect(gallery.cover_photo).to eq(upload2)
    end

    it "returns the first upload when cover_upload is not set" do
      gallery = create(:gallery)
      upload1 = create(:upload, gallery: gallery)
      upload2 = create(:upload, gallery: gallery)

      expect(gallery.cover_photo).to eq(upload1)
    end

    it "returns nil when there are no uploads" do
      gallery = create(:gallery)

      expect(gallery.cover_photo).to be_nil
    end
  end
end
