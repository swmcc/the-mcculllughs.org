require 'rails_helper'

RSpec.describe Upload, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:gallery) }
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
end
