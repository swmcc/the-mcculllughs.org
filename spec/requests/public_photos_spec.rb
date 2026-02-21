require 'rails_helper'

RSpec.describe "PublicPhotos", type: :request do
  let(:user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }

  describe "GET /p/:short_code" do
    context "when upload is public" do
      it "displays the photo" do
        upload = create(:upload, user: user, gallery: gallery, is_public: true)

        get "/p/#{upload.short_code}"

        expect(response).to have_http_status(:ok)
      end
    end

    context "when upload is private" do
      it "returns 404 for anonymous users" do
        upload = create(:upload, user: user, gallery: gallery, is_public: false)

        get "/p/#{upload.short_code}"

        expect(response).to have_http_status(:not_found)
      end

      it "displays the photo for the gallery owner" do
        upload = create(:upload, user: user, gallery: gallery, is_public: false)
        login_as user, scope: :user

        get "/p/#{upload.short_code}"

        expect(response).to have_http_status(:ok)
      end

      it "displays the photo for admin users" do
        upload = create(:upload, user: user, gallery: gallery, is_public: false)
        admin = create(:user, :admin)
        login_as admin, scope: :user

        get "/p/#{upload.short_code}"

        expect(response).to have_http_status(:ok)
      end
    end

    context "when short_code does not exist" do
      it "returns 404" do
        get "/p/NOTFOUND"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /p/:short_code" do
    context "when user is the gallery owner" do
      before { login_as user, scope: :user }

      it "updates is_public to true" do
        upload = create(:upload, user: user, gallery: gallery, is_public: false)

        patch "/p/#{upload.short_code}", params: { upload: { is_public: true } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(upload.reload.is_public).to be true
      end

      it "updates is_public to false" do
        upload = create(:upload, user: user, gallery: gallery, is_public: true)

        patch "/p/#{upload.short_code}", params: { upload: { is_public: false } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(upload.reload.is_public).to be false
      end

      it "returns JSON response with is_public status" do
        upload = create(:upload, user: user, gallery: gallery, is_public: false)

        patch "/p/#{upload.short_code}", params: { upload: { is_public: true } }, as: :json

        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["is_public"]).to be true
      end
    end

    context "when user is an admin" do
      it "allows updating is_public" do
        admin = create(:user, :admin)
        upload = create(:upload, user: user, gallery: gallery, is_public: false)
        login_as admin, scope: :user

        patch "/p/#{upload.short_code}", params: { upload: { is_public: true } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(upload.reload.is_public).to be true
      end
    end

    context "when user is not authorized" do
      it "returns 403 for other users" do
        other_user = create(:user)
        upload = create(:upload, user: user, gallery: gallery, is_public: true)
        login_as other_user, scope: :user

        patch "/p/#{upload.short_code}", params: { upload: { is_public: false } }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(upload.reload.is_public).to be true
      end

      it "returns 403 for anonymous users" do
        upload = create(:upload, user: user, gallery: gallery, is_public: true)

        patch "/p/#{upload.short_code}", params: { upload: { is_public: false } }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(upload.reload.is_public).to be true
      end
    end
  end
end
