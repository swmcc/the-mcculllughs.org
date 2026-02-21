# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }

  before { sign_in user }

  describe "GET /search" do
    it "returns search page" do
      get search_path
      expect(response).to have_http_status(:success)
    end

    it "finds uploads by title" do
      upload = create(:upload, gallery: gallery, user: user, title: "Birthday Party")

      get search_path, params: { q: "birthday" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Birthday Party")
      expect(response.body).to include("1 photo found")
    end

    it "shows no results message when nothing found" do
      get search_path, params: { q: "nonexistent" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("No photos found")
    end

    it "does not find uploads from other users" do
      other_user = create(:user)
      other_gallery = create(:gallery, user: other_user)
      create(:upload, gallery: other_gallery, user: other_user, title: "Secret Photo")

      get search_path, params: { q: "secret" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("No photos found")
    end
  end
end
