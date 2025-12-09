require 'rails_helper'

RSpec.describe "Uploads", type: :request do
  describe "GET /create" do
    it "returns http success" do
      get "/uploads/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/uploads/destroy"
      expect(response).to have_http_status(:success)
    end
  end
end
