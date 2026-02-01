require 'rails_helper'

RSpec.describe Gallery, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
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

        expect(Gallery.recent).to eq([new_gallery, old_gallery])
      end
    end
  end
end
