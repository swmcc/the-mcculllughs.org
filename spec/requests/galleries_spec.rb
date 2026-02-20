require 'rails_helper'

RSpec.describe "Galleries", type: :request do
  let(:user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }

  before { login_as user, scope: :user }

  describe "GET /galleries" do
    it "returns http success" do
      get "/galleries"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /galleries/:id" do
    it "returns http success" do
      get "/galleries/#{gallery.id}"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /galleries/new" do
    it "returns http success" do
      get "/galleries/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /galleries" do
    it "creates a gallery and redirects" do
      expect {
        post "/galleries", params: { gallery: { title: "Test Gallery", description: "Test" } }
      }.to change(Gallery, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "creates a gallery via Turbo and redirects" do
      expect {
        post "/galleries",
          params: { gallery: { title: "Test Gallery", description: "Test" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.to change(Gallery, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end

    it "returns unprocessable_entity for invalid gallery via Turbo" do
      post "/galleries",
        params: { gallery: { title: "", description: "Test" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /galleries/:id/edit" do
    it "returns http success" do
      get "/galleries/#{gallery.id}/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /galleries/:id" do
    it "updates the gallery and redirects" do
      patch "/galleries/#{gallery.id}", params: { gallery: { title: "Updated Title" } }
      expect(response).to have_http_status(:redirect)
      expect(gallery.reload.title).to eq("Updated Title")
    end
  end

  describe "DELETE /galleries/:id" do
    it "deletes the gallery and redirects" do
      gallery # create it first
      expect {
        delete "/galleries/#{gallery.id}"
      }.to change(Gallery, :count).by(-1)
      expect(response).to have_http_status(:redirect)
    end
  end
end
