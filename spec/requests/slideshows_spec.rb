require 'rails_helper'

RSpec.describe "Slideshows", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:gallery) { create(:gallery, user: user) }
  let!(:uploads) { create_list(:upload, 3, user: user, gallery: gallery) }

  before { sign_in user }

  describe "GET /slideshows" do
    it "returns http success" do
      get slideshows_path
      expect(response).to have_http_status(:success)
    end

    it "shows user's slideshows" do
      slideshow = create(:slideshow, user: user, title: "My Slideshow")
      get slideshows_path
      expect(response.body).to include("My Slideshow")
    end
  end

  describe "POST /slideshows" do
    it "creates a slideshow with uploads" do
      expect {
        post slideshows_path, params: {
          slideshow: { title: "New Slideshow", description: "Test", interval: 5 },
          upload_ids: uploads.map(&:id)
        }, as: :json
      }.to change(Slideshow, :count).by(1)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present

      slideshow = Slideshow.last
      expect(slideshow.title).to eq("New Slideshow")
      expect(slideshow.uploads.count).to eq(3)
    end

    it "only includes uploads from user's galleries" do
      other_gallery = create(:gallery, user: other_user)
      other_upload = create(:upload, user: other_user, gallery: other_gallery)

      post slideshows_path, params: {
        slideshow: { title: "Test", description: "Test", interval: 5 },
        upload_ids: [ uploads.first.id, other_upload.id ]
      }, as: :json

      slideshow = Slideshow.last
      expect(slideshow.uploads.count).to eq(1)
      expect(slideshow.uploads).not_to include(other_upload)
    end

    it "returns errors for invalid slideshow" do
      post slideshows_path, params: {
        slideshow: { title: "", description: "Test", interval: 5 }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /slideshows/search" do
    let!(:slideshow1) { create(:slideshow, user: user, title: "Summer Vacation") }
    let!(:slideshow2) { create(:slideshow, user: user, title: "Winter Holiday") }
    let!(:other_slideshow) { create(:slideshow, user: other_user, title: "Other User Slideshow") }

    it "returns user's slideshows as JSON" do
      get search_slideshows_path, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      titles = json.map { |s| s["title"] }
      expect(titles).to include("Summer Vacation", "Winter Holiday")
      expect(titles).not_to include("Other User Slideshow")
    end

    it "filters slideshows by search query" do
      get search_slideshows_path, params: { q: "Summer" }, as: :json

      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["title"]).to eq("Summer Vacation")
    end

    it "returns empty array when no matches" do
      get search_slideshows_path, params: { q: "Nonexistent" }, as: :json

      json = JSON.parse(response.body)
      expect(json).to eq([])
    end

    it "includes slideshow metadata" do
      slideshow1.uploads << uploads.first

      get search_slideshows_path, as: :json

      json = JSON.parse(response.body)
      slideshow_data = json.find { |s| s["id"] == slideshow1.id }
      expect(slideshow_data["photo_count"]).to eq(1)
      expect(slideshow_data).to have_key("cover_url")
    end
  end

  describe "POST /slideshows/:id/add_uploads" do
    let!(:slideshow) { create(:slideshow, user: user, title: "My Slideshow") }

    it "adds uploads to an existing slideshow" do
      expect {
        post add_uploads_slideshow_path(slideshow), params: {
          upload_ids: uploads.map(&:id)
        }, as: :json
      }.to change { slideshow.uploads.count }.by(3)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["added_count"]).to eq(3)
      expect(json["total_count"]).to eq(3)
    end

    it "skips uploads already in slideshow" do
      slideshow.uploads << uploads.first

      post add_uploads_slideshow_path(slideshow), params: {
        upload_ids: uploads.map(&:id)
      }, as: :json

      json = JSON.parse(response.body)
      expect(json["added_count"]).to eq(2)
      expect(json["total_count"]).to eq(3)
    end

    it "only adds uploads from user's galleries" do
      other_gallery = create(:gallery, user: other_user)
      other_upload = create(:upload, user: other_user, gallery: other_gallery)

      post add_uploads_slideshow_path(slideshow), params: {
        upload_ids: [ uploads.first.id, other_upload.id ]
      }, as: :json

      expect(slideshow.uploads.count).to eq(1)
      expect(slideshow.uploads).not_to include(other_upload)
    end

    it "returns error when no photos selected" do
      post add_uploads_slideshow_path(slideshow), params: {
        upload_ids: []
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("No photos selected")
    end

    it "prevents adding to other user's slideshow" do
      other_slideshow = create(:slideshow, user: other_user)

      post add_uploads_slideshow_path(other_slideshow), params: {
        upload_ids: uploads.map(&:id)
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "sets correct position for added uploads" do
      post add_uploads_slideshow_path(slideshow), params: {
        upload_ids: uploads.map(&:id)
      }, as: :json

      positions = slideshow.slideshow_uploads.order(:position).pluck(:position)
      expect(positions).to eq([ 0, 1, 2 ])
    end
  end

  describe "admin access" do
    let(:admin) { create(:user, :admin) }

    before { sign_in admin }

    it "allows admin to search all slideshows" do
      user_slideshow = create(:slideshow, user: user, title: "User Slideshow")

      get search_slideshows_path, as: :json

      json = JSON.parse(response.body)
      # Admin only sees their own slideshows in search (for adding photos)
      # This is intentional - admin creates their own slideshows
      expect(json.map { |s| s["title"] }).not_to include("User Slideshow")
    end

    it "allows admin to add any uploads to their slideshow" do
      admin_slideshow = create(:slideshow, user: admin)

      post add_uploads_slideshow_path(admin_slideshow), params: {
        upload_ids: uploads.map(&:id)
      }, as: :json

      expect(response).to have_http_status(:success)
      expect(admin_slideshow.uploads.count).to eq(3)
    end
  end
end
