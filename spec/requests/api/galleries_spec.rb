require 'rails_helper'

RSpec.describe "Api::Galleries", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, :photos_create, user: user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key.key}" } }

  describe "GET /api/galleries" do
    let!(:zebra_gallery) { create(:gallery, user: user, title: "Zebra Trip") }
    let!(:apple_gallery) { create(:gallery, user: user, title: "Apple Picking") }
    let!(:other_gallery) { create(:gallery, title: "Someone Else's Gallery") }

    it "returns 401 without auth header" do
      get api_galleries_path, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an invalid key" do
      get api_galleries_path, headers: { "Authorization" => "Bearer invalid_key" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with a revoked key" do
      revoked_key = create(:api_key, :revoked, user: user)
      get api_galleries_path, headers: { "Authorization" => "Bearer #{revoked_key.key}" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "allows a photos:create scoped key" do
      get api_galleries_path, headers: auth_headers, as: :json
      expect(response).to have_http_status(:success)
    end

    it "allows an admin scoped key" do
      admin_key = create(:api_key, user: user)
      get api_galleries_path, headers: { "Authorization" => "Bearer #{admin_key.key}" }, as: :json
      expect(response).to have_http_status(:success)
    end

    it "returns only the key owner's galleries, ordered by title" do
      get api_galleries_path, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["galleries"].map { |g| g["title"] }).to eq([ "Apple Picking", "Zebra Trip" ])
      expect(json["galleries"].map { |g| g["id"] }).not_to include(other_gallery.id)
    end

    it "includes an uploads_count for each gallery" do
      create_list(:upload, 2, user: user, gallery: zebra_gallery)

      get api_galleries_path, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      counts = json["galleries"].to_h { |g| [ g["title"], g["uploads_count"] ] }
      expect(counts).to eq("Apple Picking" => 0, "Zebra Trip" => 2)
    end
  end
end
