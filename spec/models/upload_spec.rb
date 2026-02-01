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
  end

  describe "callbacks" do
    it "enqueues ProcessMediaJob after create" do
      user = create(:user)
      gallery = create(:gallery, user: user)

      expect {
        create(:upload, user: user, gallery: gallery)
      }.to have_enqueued_job(ProcessMediaJob)
    end
  end
end
