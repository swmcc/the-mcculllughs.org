require 'rails_helper'

RSpec.describe "Uploads", type: :request do
  let(:user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }

  before { login_as user, scope: :user }

  describe "POST /galleries/:gallery_id/uploads" do
    it "creates an upload and redirects" do
      file = fixture_file_upload(
        Rails.root.join("spec/fixtures/files/test_image.jpg"),
        "image/jpeg"
      )

      expect {
        post "/galleries/#{gallery.id}/uploads", params: { upload: { file: file } }
      }.to change(Upload, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /uploads/:id" do
    it "deletes the upload and redirects" do
      upload = create(:upload, user: user, gallery: gallery)
      expect {
        delete "/uploads/#{upload.id}"
      }.to change(Upload, :count).by(-1)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "PATCH /uploads/:id" do
    it "updates title and caption" do
      upload = create(:upload, user: user, gallery: gallery, title: "Old", caption: "Old caption")

      patch "/uploads/#{upload.id}", params: {
        upload: { title: "New Title", caption: "New caption" }
      }, as: :json

      expect(response).to have_http_status(:ok)
      upload.reload
      expect(upload.title).to eq("New Title")
      expect(upload.caption).to eq("New caption")
    end

    it "updates date_taken" do
      upload = create(:upload, user: user, gallery: gallery)

      patch "/uploads/#{upload.id}", params: {
        upload: { date_taken: "2024-06-15" }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(upload.reload.date_taken).to eq(Date.new(2024, 6, 15))
    end

    it "updates is_public" do
      upload = create(:upload, user: user, gallery: gallery, is_public: false)

      patch "/uploads/#{upload.id}", params: {
        upload: { is_public: true }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(upload.reload.is_public).to be true
    end

    it "returns JSON with updated values" do
      upload = create(:upload, user: user, gallery: gallery)

      patch "/uploads/#{upload.id}", params: {
        upload: { title: "Test", is_public: true }
      }, as: :json

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["title"]).to eq("Test")
      expect(json["is_public"]).to be true
      expect(json["short_code"]).to eq(upload.short_code)
    end

    context "when user is not authorized" do
      it "returns 403 for other users" do
        other_user = create(:user)
        other_gallery = create(:gallery, user: other_user)
        upload = create(:upload, user: other_user, gallery: other_gallery)

        patch "/uploads/#{upload.id}", params: {
          upload: { title: "Hacked" }
        }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(upload.reload.title).not_to eq("Hacked")
      end
    end

    context "when user is admin" do
      let(:admin) { create(:user, :admin) }

      before { login_as admin, scope: :user }

      it "allows updating any upload" do
        upload = create(:upload, user: user, gallery: gallery, title: "Original")

        patch "/uploads/#{upload.id}", params: {
          upload: { title: "Admin Edit" }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(upload.reload.title).to eq("Admin Edit")
      end
    end
  end
end
