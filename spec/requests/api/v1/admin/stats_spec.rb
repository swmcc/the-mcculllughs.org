require "rails_helper"

RSpec.describe "Api::V1::Admin::Stats", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:api_key) { create(:api_key, user: admin) }
  let(:headers) { { "Authorization" => "Bearer #{api_key.key}" } }

  describe "GET /api/v1/admin/stats" do
    it "returns stats" do
      get "/api/v1/admin/stats", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to include("photos", "galleries", "api_keys")
      expect(json["photos"]).to include("total", "pending", "processing", "completed", "failed", "with_embedding")
    end

    it "returns unauthorized without key" do
      get "/api/v1/admin/stats"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
