require 'rails_helper'

RSpec.describe "Api::Uploads", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key.key}" } }

  let(:gallery) { create(:gallery, user: user) }
  let!(:upload_without_analysis) { create(:upload, user: user, gallery: gallery, analysis_data: nil) }
  let!(:upload_with_analysis) { create(:upload, user: user, gallery: gallery, analysis_data: { "event" => "test" }) }

  describe "GET /api/uploads/pending" do
    it "returns 401 without auth header" do
      get pending_api_uploads_path, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with invalid key" do
      get pending_api_uploads_path, headers: { "Authorization" => "Bearer invalid_key" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with revoked key" do
      revoked_key = create(:api_key, :revoked, user: user)
      get pending_api_uploads_path, headers: { "Authorization" => "Bearer #{revoked_key.key}" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with expired key" do
      expired_key = create(:api_key, :expired, user: user)
      get pending_api_uploads_path, headers: { "Authorization" => "Bearer #{expired_key.key}" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns only uploads without analysis_data" do
      get pending_api_uploads_path, headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      upload_ids = json["uploads"].map { |u| u["id"] }
      expect(upload_ids).to include(upload_without_analysis.id)
      expect(upload_ids).not_to include(upload_with_analysis.id)
    end

    it "includes correct fields in response" do
      get pending_api_uploads_path, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      upload_data = json["uploads"].find { |u| u["id"] == upload_without_analysis.id }

      expect(upload_data).to include(
        "id" => upload_without_analysis.id,
        "short_code" => upload_without_analysis.short_code
      )
      expect(upload_data).to have_key("image_url")
      expect(upload_data).to have_key("created_at")
    end

    it "includes pagination info" do
      get pending_api_uploads_path, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json).to have_key("total")
      expect(json).to have_key("page")
      expect(json).to have_key("per_page")
    end

    it "respects pagination params" do
      get pending_api_uploads_path, params: { page: 1, per_page: 1 }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["per_page"]).to eq(1)
      expect(json["uploads"].length).to eq(1)
    end

    it "caps per_page at 100" do
      get pending_api_uploads_path, params: { per_page: 500 }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["per_page"]).to eq(100)
    end

    it "updates last_used_at on API key" do
      expect(api_key.last_used_at).to be_nil

      get pending_api_uploads_path, headers: auth_headers, as: :json

      api_key.reload
      expect(api_key.last_used_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "PATCH /api/uploads/:id/analysis" do
    let(:analysis_data) do
      {
        description: "A family gathered around a Christmas tree opening presents",
        mood: "joyful",
        location: {
          setting: "living room",
          type: "indoor",
          specific: nil
        },
        era: {
          decade: "1990s",
          confidence: "medium",
          reasoning: "Clothing styles and photo quality suggest early 90s"
        },
        people: [
          { description: "adult woman", estimated_age: "30s", position: "left" },
          { description: "young child", estimated_age: "5-7", position: "center" }
        ],
        categories: %w[christmas family holiday],
        colors: %w[red green gold],
        objects: [ "christmas tree", "presents", "ornaments" ]
      }
    end

    it "returns 401 without auth header" do
      patch analysis_api_upload_path(upload_without_analysis), as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates analysis_data successfully" do
      patch analysis_api_upload_path(upload_without_analysis),
            params: { analysis_data: analysis_data },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true

      upload_without_analysis.reload
      expect(upload_without_analysis.analysis_data["description"]).to include("Christmas tree")
      expect(upload_without_analysis.analysis_data["categories"]).to eq(%w[christmas family holiday])
      expect(upload_without_analysis.analysis_data["location"]["setting"]).to eq("living room")
      expect(upload_without_analysis.analysis_data["era"]["decade"]).to eq("1990s")
    end

    it "updates embedding when provided" do
      embedding = Array.new(768) { rand(-1.0..1.0) }

      patch analysis_api_upload_path(upload_without_analysis),
            params: { analysis_data: analysis_data, embedding: embedding },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:success)

      upload_without_analysis.reload
      expect(upload_without_analysis.embedding).to be_present
      expect(upload_without_analysis.embedding.length).to eq(768)
    end

    it "updates analysis_data and returns success" do
      patch analysis_api_upload_path(upload_without_analysis),
            params: { analysis_data: analysis_data },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["id"]).to eq(upload_without_analysis.id)
    end

    it "returns 404 for non-existent upload" do
      patch analysis_api_upload_path(id: 999999),
            params: { analysis_data: analysis_data },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
