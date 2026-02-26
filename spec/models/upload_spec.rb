require 'rails_helper'

RSpec.describe Upload, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:gallery) }
    it { is_expected.to have_one(:gallery_as_cover).class_name("Gallery").with_foreign_key("cover_upload_id").dependent(:nullify) }
    it { is_expected.to have_one_attached(:file) }
    it { is_expected.to have_one_attached(:thumbnail) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:file) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:gallery) }

    describe "short_code" do
      subject { create(:upload) }
      it { is_expected.to validate_uniqueness_of(:short_code) }

      it "is required" do
        upload = create(:upload)
        upload.short_code = nil
        expect(upload).not_to be_valid
        expect(upload.errors[:short_code]).to include("can't be blank")
      end
    end

    describe "file content type validation" do
      let(:user) { create(:user) }
      let(:gallery) { create(:gallery, user: user) }

      it "accepts valid image content types" do
        %w[image/jpeg image/png image/gif image/webp].each do |content_type|
          upload = build(:upload, user: user, gallery: gallery)
          upload.file.attach(
            io: StringIO.new("fake image data"),
            filename: "test.jpg",
            content_type: content_type
          )
          expect(upload).to be_valid
        end
      end

      it "accepts valid video content types" do
        %w[video/mp4 video/quicktime].each do |content_type|
          upload = build(:upload, user: user, gallery: gallery)
          upload.file.attach(
            io: StringIO.new("fake video data"),
            filename: "test.mp4",
            content_type: content_type
          )
          expect(upload).to be_valid
        end
      end

      it "rejects invalid content types" do
        upload = build(:upload, user: user, gallery: gallery)
        upload.file.attach(
          io: StringIO.new("<?php echo 'hacked'; ?>"),
          filename: "shell.php",
          content_type: "application/x-php"
        )
        expect(upload).not_to be_valid
        expect(upload.errors[:file]).to include(/must be an image or video/)
      end

      it "rejects executable files" do
        upload = build(:upload, user: user, gallery: gallery)
        upload.file.attach(
          io: StringIO.new("MZ..."),
          filename: "malware.exe",
          content_type: "application/x-msdownload"
        )
        expect(upload).not_to be_valid
      end
    end
  end

  describe "scopes" do
    describe ".recent" do
      it "returns uploads ordered by created_at desc" do
        user = create(:user)
        gallery = create(:gallery, user: user)
        old_upload = create(:upload, user: user, gallery: gallery, created_at: 2.days.ago)
        new_upload = create(:upload, user: user, gallery: gallery, created_at: 1.day.ago)

        expect(Upload.recent).to eq([ new_upload, old_upload ])
      end
    end

    describe ".publicly_visible" do
      it "returns only public uploads" do
        user = create(:user)
        gallery = create(:gallery, user: user)
        public_upload = create(:upload, user: user, gallery: gallery, is_public: true)
        create(:upload, user: user, gallery: gallery, is_public: false)

        expect(Upload.publicly_visible).to eq([ public_upload ])
      end
    end
  end

  describe "callbacks" do
    it "enqueues ProcessMediaJob after create" do
      user = create(:user)
      gallery = create(:gallery, user: user)

      expect {
        create(:upload, user: user, gallery: gallery)
      }.to have_enqueued_job(ProcessMediaJob)
    end

    it "generates a short_code before validation on create" do
      user = create(:user)
      gallery = create(:gallery, user: user)
      upload = create(:upload, user: user, gallery: gallery)

      expect(upload.short_code).to be_present
      expect(upload.short_code.length).to eq(6)
    end

    it "does not overwrite existing short_code" do
      user = create(:user)
      gallery = create(:gallery, user: user)
      upload = build(:upload, user: user, gallery: gallery, short_code: "ABC123")
      upload.save!

      expect(upload.short_code).to eq("ABC123")
    end
  end

  describe "#is_public" do
    it "defaults to false" do
      user = create(:user)
      gallery = create(:gallery, user: user)
      upload = create(:upload, user: user, gallery: gallery)

      expect(upload.is_public).to be false
    end

    it "can be set to true" do
      user = create(:user)
      gallery = create(:gallery, user: user)
      upload = create(:upload, user: user, gallery: gallery, is_public: true)

      expect(upload.is_public).to be true
    end
  end

  describe "#cover?" do
    it "returns true when upload is the gallery cover" do
      gallery = create(:gallery)
      upload = create(:upload, gallery: gallery)
      gallery.update!(cover_upload: upload)

      expect(upload.cover?).to be true
    end

    it "returns false when upload is not the gallery cover" do
      gallery = create(:gallery)
      upload = create(:upload, gallery: gallery)

      expect(upload.cover?).to be false
    end
  end

  describe "clearing cover on destroy" do
    it "clears cover_upload_id when cover photo is deleted" do
      gallery = create(:gallery)
      upload = create(:upload, gallery: gallery)
      gallery.update!(cover_upload: upload)

      expect(gallery.reload.cover_upload_id).to eq(upload.id)

      upload.destroy

      expect(gallery.reload.cover_upload_id).to be_nil
    end

    it "does not affect gallery when non-cover photo is deleted" do
      gallery = create(:gallery)
      cover = create(:upload, gallery: gallery)
      other = create(:upload, gallery: gallery)
      gallery.update!(cover_upload: cover)

      other.destroy

      expect(gallery.reload.cover_upload_id).to eq(cover.id)
    end
  end
end
