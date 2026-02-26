require 'rails_helper'

RSpec.describe "Authorization Security", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, role: :admin) }

  let(:user_gallery) { create(:gallery, user: user) }
  let(:other_gallery) { create(:gallery, user: other_user) }

  describe "GalleriesController authorization" do
    before { login_as user, scope: :user }

    describe "viewing galleries" do
      it "allows viewing any gallery" do
        get "/galleries/#{other_gallery.id}"
        expect(response).to have_http_status(:success)
      end
    end

    describe "editing galleries" do
      it "prevents editing other users' galleries" do
        get "/galleries/#{other_gallery.id}/edit"
        expect(response).to redirect_to(galleries_path)
      end

      it "allows editing own galleries" do
        get "/galleries/#{user_gallery.id}/edit"
        expect(response).to have_http_status(:success)
      end
    end

    describe "updating galleries" do
      it "prevents updating other users' galleries" do
        patch "/galleries/#{other_gallery.id}", params: { gallery: { title: "Hacked" } }
        expect(response).to redirect_to(galleries_path)
        expect(other_gallery.reload.title).not_to eq("Hacked")
      end

      it "allows updating own galleries" do
        patch "/galleries/#{user_gallery.id}", params: { gallery: { title: "Updated" } }
        expect(response).to redirect_to(gallery_path(user_gallery))
        expect(user_gallery.reload.title).to eq("Updated")
      end
    end

    describe "deleting galleries" do
      it "prevents deleting other users' galleries" do
        other_gallery # create it
        expect {
          delete "/galleries/#{other_gallery.id}"
        }.not_to change(Gallery, :count)
        expect(response).to redirect_to(galleries_path)
        expect(Gallery.exists?(other_gallery.id)).to be true
      end

      it "allows deleting own galleries" do
        user_gallery # create it
        expect {
          delete "/galleries/#{user_gallery.id}"
        }.to change(Gallery, :count).by(-1)
      end
    end

    describe "admin access" do
      before { login_as admin, scope: :user }

      it "allows admins to edit any gallery" do
        get "/galleries/#{other_gallery.id}/edit"
        expect(response).to have_http_status(:success)
      end

      it "allows admins to delete any gallery" do
        other_gallery # create it
        expect {
          delete "/galleries/#{other_gallery.id}"
        }.to change(Gallery, :count).by(-1)
      end
    end
  end

  describe "UploadsController authorization" do
    let(:user_upload) { create(:upload, user: user, gallery: user_gallery) }
    let(:other_upload) { create(:upload, user: other_user, gallery: other_gallery) }

    before { login_as user, scope: :user }

    describe "creating uploads" do
      it "prevents creating uploads in other users' galleries" do
        file = fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg')
        expect {
          post "/galleries/#{other_gallery.id}/uploads", params: { upload: { file: file } }
        }.not_to change(Upload, :count)
        expect(response).to redirect_to(galleries_path)
      end

      it "allows creating uploads in own galleries" do
        file = fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg')
        expect {
          post "/galleries/#{user_gallery.id}/uploads", params: { upload: { file: file } }
        }.to change(Upload, :count).by(1)
      end
    end

    describe "updating uploads" do
      it "prevents updating other users' uploads" do
        patch "/uploads/#{other_upload.id}", params: { upload: { title: "Hacked" } }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(other_upload.reload.title).not_to eq("Hacked")
      end

      it "allows updating own uploads" do
        patch "/uploads/#{user_upload.id}", params: { upload: { title: "Updated" } }, as: :json
        expect(response).to have_http_status(:success)
        expect(user_upload.reload.title).to eq("Updated")
      end
    end

    describe "deleting uploads" do
      it "prevents deleting other users' uploads" do
        other_upload # create it
        expect {
          delete "/uploads/#{other_upload.id}"
        }.not_to change(Upload, :count)
        expect(response).to redirect_to(galleries_path)
        expect(Upload.exists?(other_upload.id)).to be true
      end

      it "allows deleting own uploads" do
        user_upload # create it
        expect {
          delete "/uploads/#{user_upload.id}"
        }.to change(Upload, :count).by(-1)
      end
    end

    describe "setting cover photo" do
      it "prevents setting cover on other users' galleries" do
        patch "/uploads/#{other_upload.id}/set_cover"
        expect(response).to redirect_to(galleries_path)
        expect(other_gallery.reload.cover_upload_id).not_to eq(other_upload.id)
      end

      it "allows setting cover on own galleries" do
        patch "/uploads/#{user_upload.id}/set_cover"
        expect(response).to redirect_to(user_gallery)
        expect(user_gallery.reload.cover_upload_id).to eq(user_upload.id)
      end
    end
  end

  describe "SlideshowsController authorization" do
    let(:user_upload) { create(:upload, user: user, gallery: user_gallery) }
    let(:other_upload) { create(:upload, user: other_user, gallery: other_gallery) }

    before { login_as user, scope: :user }

    describe "creating slideshows with uploads" do
      it "prevents adding other users' uploads to slideshows" do
        post "/slideshows", params: {
          slideshow: { title: "Test Slideshow" },
          upload_ids: [ other_upload.id ]
        }, as: :json

        expect(response).to have_http_status(:success)
        slideshow = Slideshow.last
        expect(slideshow.uploads).not_to include(other_upload)
      end

      it "allows adding own uploads to slideshows" do
        post "/slideshows", params: {
          slideshow: { title: "Test Slideshow" },
          upload_ids: [ user_upload.id ]
        }, as: :json

        expect(response).to have_http_status(:success)
        slideshow = Slideshow.last
        expect(slideshow.uploads).to include(user_upload)
      end

      it "filters out unauthorized uploads but keeps authorized ones" do
        post "/slideshows", params: {
          slideshow: { title: "Test Slideshow" },
          upload_ids: [ user_upload.id, other_upload.id ]
        }, as: :json

        expect(response).to have_http_status(:success)
        slideshow = Slideshow.last
        expect(slideshow.uploads).to include(user_upload)
        expect(slideshow.uploads).not_to include(other_upload)
      end
    end

    describe "admin access" do
      before { login_as admin, scope: :user }

      it "allows admins to add any uploads to slideshows" do
        post "/slideshows", params: {
          slideshow: { title: "Admin Slideshow" },
          upload_ids: [ other_upload.id ]
        }, as: :json

        expect(response).to have_http_status(:success)
        slideshow = Slideshow.last
        expect(slideshow.uploads).to include(other_upload)
      end
    end
  end
end
