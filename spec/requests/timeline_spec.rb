# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Timeline", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, role: :admin) }
  let(:gallery) { create(:gallery, user: user) }

  describe "GET /timeline" do
    context "when not signed in" do
      it "redirects to sign in" do
        get timeline_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns success" do
        get timeline_path
        expect(response).to have_http_status(:success)
      end

      it "groups photos by decade" do
        create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))
        create(:upload, gallery: gallery, user: user, date_taken: Date.new(1998, 3, 20))

        get timeline_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("1970s")
        expect(response.body).to include("1990s")
      end

      it "skips uploads without date_taken" do
        create(:upload, gallery: gallery, user: user, date_taken: nil)

        get timeline_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("No dated photos")
      end

      it "only shows current user's photos" do
        other_user = create(:user)
        other_gallery = create(:gallery, user: other_user)
        create(:upload, gallery: other_gallery, user: other_user, date_taken: Date.new(1985, 5, 10))

        get timeline_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("No dated photos")
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "shows all users' photos" do
        create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

        get timeline_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("1970s")
      end
    end
  end

  describe "GET /timeline/:decade" do
    before { sign_in user }

    it "returns success" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_decade_path(decade: "1970s")

      expect(response).to have_http_status(:success)
    end

    it "shows years within the decade" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1975, 3, 10))
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_decade_path(decade: "1970s")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("1975")
      expect(response.body).to include("1978")
    end

    it "includes breadcrumbs" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_decade_path(decade: "1970s")

      expect(response.body).to include("Timeline")
      expect(response.body).to include("1970s")
    end

    it "shows empty state when no photos in decade" do
      get timeline_decade_path(decade: "2010s")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("No photos in the 2010s")
    end
  end

  describe "GET /timeline/:decade/:year" do
    before { sign_in user }

    it "returns success" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_year_path(decade: "1970s", year: "1978")

      expect(response).to have_http_status(:success)
    end

    it "shows months within the year" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 3, 10))
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_year_path(decade: "1970s", year: "1978")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("March")
      expect(response.body).to include("June")
    end

    it "includes breadcrumbs with links" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_year_path(decade: "1970s", year: "1978")

      expect(response.body).to include("Timeline")
      expect(response.body).to include("1970s")
      expect(response.body).to include("1978")
    end
  end

  describe "GET /timeline/:decade/:year/:month" do
    before { sign_in user }

    it "returns success" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_month_path(decade: "1970s", year: "1978", month: "6")

      expect(response).to have_http_status(:success)
    end

    it "shows all photos from the month" do
      upload1 = create(:upload, gallery: gallery, user: user, title: "Photo One", date_taken: Date.new(1978, 6, 10))
      upload2 = create(:upload, gallery: gallery, user: user, title: "Photo Two", date_taken: Date.new(1978, 6, 20))

      get timeline_month_path(decade: "1970s", year: "1978", month: "6")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("2 photos")
    end

    it "includes full breadcrumb navigation" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_month_path(decade: "1970s", year: "1978", month: "6")

      expect(response.body).to include("Timeline")
      expect(response.body).to include("1970s")
      expect(response.body).to include("1978")
      expect(response.body).to include("June")
    end

    it "shows photo grid" do
      create(:upload, gallery: gallery, user: user, date_taken: Date.new(1978, 6, 15))

      get timeline_month_path(decade: "1970s", year: "1978", month: "6")

      expect(response.body).to include("data-controller=\"search-lightbox\"")
    end
  end
end
