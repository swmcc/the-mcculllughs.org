# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchService do
  let(:user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }

  describe "#call" do
    context "with blank query" do
      it "returns no results" do
        results = described_class.new(query: "", user: user).call
        expect(results).to be_empty
      end

      it "returns no results for nil query" do
        results = described_class.new(query: nil, user: user).call
        expect(results).to be_empty
      end
    end

    context "searching by title" do
      it "finds uploads matching title" do
        upload = create(:upload, gallery: gallery, user: user, title: "Birthday Party")
        create(:upload, gallery: gallery, user: user, title: "Wedding")

        results = described_class.new(query: "birthday", user: user).call
        expect(results).to contain_exactly(upload)
      end

      it "is case insensitive" do
        upload = create(:upload, gallery: gallery, user: user, title: "Birthday Party")

        results = described_class.new(query: "BIRTHDAY", user: user).call
        expect(results).to contain_exactly(upload)
      end
    end

    context "searching by caption" do
      it "finds uploads matching caption" do
        upload = create(:upload, gallery: gallery, user: user, caption: "Fun at the beach")
        create(:upload, gallery: gallery, user: user, caption: "Mountain trip")

        results = described_class.new(query: "beach", user: user).call
        expect(results).to contain_exactly(upload)
      end
    end

    context "searching by date" do
      it "finds uploads by year" do
        upload1998 = create(:upload, gallery: gallery, user: user, date_taken: Date.new(1998, 6, 15))
        create(:upload, gallery: gallery, user: user, date_taken: Date.new(1999, 6, 15))

        results = described_class.new(query: "1998", user: user).call
        expect(results).to contain_exactly(upload1998)
      end

      it "finds uploads by month and year" do
        aug_upload = create(:upload, gallery: gallery, user: user, date_taken: Date.new(1998, 8, 15))
        create(:upload, gallery: gallery, user: user, date_taken: Date.new(1998, 9, 15))

        results = described_class.new(query: "August 1998", user: user).call
        expect(results).to contain_exactly(aug_upload)
      end

      it "finds uploads by full date" do
        upload = create(:upload, gallery: gallery, user: user, date_taken: Date.new(1979, 4, 11))
        create(:upload, gallery: gallery, user: user, date_taken: Date.new(1979, 4, 12))

        results = described_class.new(query: "11-04-1979", user: user).call
        expect(results).to contain_exactly(upload)
      end
    end

    context "searching with text and date combined" do
      it "filters by both text and date" do
        birthday_1998 = create(:upload, gallery: gallery, user: user,
                               title: "Birthday", date_taken: Date.new(1998, 8, 15))
        create(:upload, gallery: gallery, user: user,
               title: "Birthday", date_taken: Date.new(1999, 8, 15))
        create(:upload, gallery: gallery, user: user,
               title: "Wedding", date_taken: Date.new(1998, 8, 20))

        results = described_class.new(query: "birthday 1998", user: user).call
        expect(results).to contain_exactly(birthday_1998)
      end
    end

    context "user scope" do
      it "only returns uploads from user's galleries" do
        other_user = create(:user)
        other_gallery = create(:gallery, user: other_user)

        my_upload = create(:upload, gallery: gallery, user: user, title: "My Photo")
        create(:upload, gallery: other_gallery, user: other_user, title: "My Photo")

        results = described_class.new(query: "photo", user: user).call
        expect(results).to contain_exactly(my_upload)
      end
    end
  end
end
