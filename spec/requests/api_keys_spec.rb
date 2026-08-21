require 'rails_helper'

RSpec.describe "ApiKeys", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /api_keys/new" do
    it "defaults the scope select to photos:create" do
      get new_api_key_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("photos:create")
    end
  end

  describe "POST /api_keys" do
    it "persists the requested scope" do
      expect {
        post api_keys_path, params: { api_key: { name: "Apple Shortcut", scope: "photos:create" } }
      }.to change { user.api_keys.count }.by(1)

      expect(user.api_keys.last.scope).to eq("photos:create")
    end

    it "persists an admin scope when requested" do
      post api_keys_path, params: { api_key: { name: "Indexatron", scope: "admin" } }

      expect(user.api_keys.last.scope).to eq("admin")
    end

    it "rejects an unknown scope" do
      expect {
        post api_keys_path, params: { api_key: { name: "Sneaky", scope: "root" } }
      }.not_to change { ApiKey.count }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
