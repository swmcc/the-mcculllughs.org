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
end
