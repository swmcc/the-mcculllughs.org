require "rails_helper"

RSpec.describe "Api::V1::Admin::Photos", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:api_key) { create(:api_key, user: admin) }
  let(:headers) { { "Authorization" => "Bearer #{api_key.key}" } }
  let(:gallery) { create(:gallery, user: admin) }

  describe "GET /api/v1/admin/photos" do
    context "with valid API key" do
      before do
        create_list(:upload, 3, gallery: gallery, user: admin)
      end

      it "returns photos" do
        get "/api/v1/admin/photos", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["photos"].length).to eq(3)
        expect(json["meta"]).to include("total", "pending", "processing", "completed", "failed")
      end

      it "filters by status" do
        Upload.first.update!(analysis_status: "completed")

        get "/api/v1/admin/photos", params: { status: "pending" }, headers: headers

        json = JSON.parse(response.body)
        expect(json["photos"].length).to eq(2)
      end
    end

    context "without API key" do
      it "returns unauthorized" do
        get "/api/v1/admin/photos"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid API key" do
      it "returns unauthorized" do
        get "/api/v1/admin/photos", headers: { "Authorization" => "Bearer invalid_key" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with read_only scope" do
      let(:api_key) { create(:api_key, :read_only, user: admin) }

      it "returns forbidden" do
        get "/api/v1/admin/photos", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/admin/photos/:id" do
    let(:upload) { create(:upload, gallery: gallery, user: admin, ) }

    it "returns photo details" do
      get "/api/v1/admin/photos/#{upload.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["photo"]["id"]).to eq(upload.id)
    end

    it "returns 404 for non-existent photo" do
      get "/api/v1/admin/photos/99999", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/admin/photos/:id/download" do
    let(:upload) { create(:upload, gallery: gallery, user: admin, ) }

    it "redirects to file" do
      get "/api/v1/admin/photos/#{upload.id}/download", headers: headers

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST /api/v1/admin/photos/:id/analysis" do
    let(:upload) { create(:upload, gallery: gallery, user: admin, ) }
    let(:analysis_data) do
      {
        description: "A family photo",
        categories: [ "family", "outdoor" ],
        people: [ { name: "John", confidence: 0.9 } ]
      }
    end
    let(:embedding) { Array.new(768) { rand(-1.0..1.0) } }

    it "saves analysis results" do
      post "/api/v1/admin/photos/#{upload.id}/analysis",
           params: { analysis: analysis_data, embedding: embedding, version: "llava-7b-v1.0" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      upload.reload
      expect(upload.analysis_status).to eq("completed")
      expect(upload.ai_analysis["description"]).to eq("A family photo")
      expect(upload.embedding).to be_present
    end
  end

  describe "POST /api/v1/admin/photos/:id/analysis_failed" do
    let(:upload) { create(:upload, gallery: gallery, user: admin, ) }

    it "marks analysis as failed" do
      post "/api/v1/admin/photos/#{upload.id}/analysis_failed",
           params: { error: "Timeout" },
           headers: headers

      expect(response).to have_http_status(:ok)
      upload.reload
      expect(upload.analysis_status).to eq("failed")
      expect(upload.analysis_error).to eq("Timeout")
    end
  end
end
