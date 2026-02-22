require "rails_helper"

RSpec.describe "Api::V1::Admin::Similarity", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:api_key) { create(:api_key, user: admin) }
  let(:headers) { { "Authorization" => "Bearer #{api_key.key}" } }

  describe "POST /api/v1/admin/similarity/search" do
    let(:embedding) { Array.new(768) { rand(-1.0..1.0) } }

    it "returns similar photos" do
      post "/api/v1/admin/similarity/search",
           params: { embedding: embedding, limit: 10 },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("results")
    end

    it "validates embedding length" do
      post "/api/v1/admin/similarity/search",
           params: { embedding: [ 1, 2, 3 ], limit: 10 },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("768")
    end

    it "returns unauthorized without key" do
      post "/api/v1/admin/similarity/search",
           params: { embedding: embedding },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
