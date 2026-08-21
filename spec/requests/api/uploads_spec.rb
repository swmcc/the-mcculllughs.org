require 'rails_helper'

RSpec.describe "Api::Uploads", type: :request do
  let(:user) { create(:user) }
  let(:api_key) { create(:api_key, user: user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key.key}" } }

  let(:gallery) { create(:gallery, user: user) }
  let!(:upload_without_analysis) { create(:upload, user: user, gallery: gallery, analysis_data: nil) }
  let!(:upload_with_analysis) { create(:upload, user: user, gallery: gallery, analysis_data: { "event" => "test" }) }

  describe "GET /api/uploads/pending" do
    it "returns 401 without auth header" do
      get pending_api_uploads_path, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with invalid key" do
      get pending_api_uploads_path, headers: { "Authorization" => "Bearer invalid_key" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with revoked key" do
      revoked_key = create(:api_key, :revoked, user: user)
      get pending_api_uploads_path, headers: { "Authorization" => "Bearer #{revoked_key.key}" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with expired key" do
      expired_key = create(:api_key, :expired, user: user)
      get pending_api_uploads_path, headers: { "Authorization" => "Bearer #{expired_key.key}" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns only uploads without analysis_data" do
      get pending_api_uploads_path, headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      upload_ids = json["uploads"].map { |u| u["id"] }
      expect(upload_ids).to include(upload_without_analysis.id)
      expect(upload_ids).not_to include(upload_with_analysis.id)
    end

    it "includes correct fields in response" do
      get pending_api_uploads_path, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      upload_data = json["uploads"].find { |u| u["id"] == upload_without_analysis.id }

      expect(upload_data).to include(
        "id" => upload_without_analysis.id,
        "short_code" => upload_without_analysis.short_code
      )
      expect(upload_data).to have_key("image_url")
      expect(upload_data).to have_key("created_at")
    end

    it "includes pagination info" do
      get pending_api_uploads_path, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json).to have_key("total")
      expect(json).to have_key("page")
      expect(json).to have_key("per_page")
    end

    it "respects pagination params" do
      get pending_api_uploads_path, params: { page: 1, per_page: 1 }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["per_page"]).to eq(1)
      expect(json["uploads"].length).to eq(1)
    end

    it "caps per_page at 100" do
      get pending_api_uploads_path, params: { per_page: 500 }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["per_page"]).to eq(100)
    end

    it "updates last_used_at on API key" do
      expect(api_key.last_used_at).to be_nil

      get pending_api_uploads_path, headers: auth_headers, as: :json

      api_key.reload
      expect(api_key.last_used_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "PATCH /api/uploads/:id/analysis" do
    let(:analysis_data) do
      {
        description: "A family gathered around a Christmas tree opening presents",
        mood: "joyful",
        location: {
          setting: "living room",
          type: "indoor",
          specific: nil
        },
        era: {
          decade: "1990s",
          confidence: "medium",
          reasoning: "Clothing styles and photo quality suggest early 90s"
        },
        people: [
          { description: "adult woman", estimated_age: "30s", position: "left" },
          { description: "young child", estimated_age: "5-7", position: "center" }
        ],
        categories: %w[christmas family holiday],
        colors: %w[red green gold],
        objects: [ "christmas tree", "presents", "ornaments" ]
      }
    end

    it "returns 401 without auth header" do
      patch analysis_api_upload_path(upload_without_analysis), as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates analysis_data successfully" do
      patch analysis_api_upload_path(upload_without_analysis),
            params: { analysis_data: analysis_data },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true

      upload_without_analysis.reload
      expect(upload_without_analysis.analysis_data["description"]).to include("Christmas tree")
      expect(upload_without_analysis.analysis_data["categories"]).to eq(%w[christmas family holiday])
      expect(upload_without_analysis.analysis_data["location"]["setting"]).to eq("living room")
      expect(upload_without_analysis.analysis_data["era"]["decade"]).to eq("1990s")
    end

    it "updates embedding when provided" do
      embedding = Array.new(768) { rand(-1.0..1.0) }

      patch analysis_api_upload_path(upload_without_analysis),
            params: { analysis_data: analysis_data, embedding: embedding },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:success)

      upload_without_analysis.reload
      expect(upload_without_analysis.embedding).to be_present
      expect(upload_without_analysis.embedding.length).to eq(768)
    end

    it "updates analysis_data and returns success" do
      patch analysis_api_upload_path(upload_without_analysis),
            params: { analysis_data: analysis_data },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["id"]).to eq(upload_without_analysis.id)
    end

    it "returns 404 for non-existent upload" do
      patch analysis_api_upload_path(id: 999999),
            params: { analysis_data: analysis_data },
            headers: auth_headers,
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/uploads" do
    let(:photos_key) { create(:api_key, :photos_create, user: user) }
    let(:photos_headers) { { "Authorization" => "Bearer #{photos_key.key}" } }
    # A gallery of its own: the shared `gallery` above already holds uploads of
    # test_image.jpg, which would trip the duplicate detection
    let(:target_gallery) { create(:gallery, user: user, title: "Holiday 1994") }

    def image_upload
      fixture_file_upload("test_image.jpg", "image/jpeg")
    end

    it "returns 401 without auth header" do
      post api_uploads_path, params: { file: image_upload }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an invalid key" do
      post api_uploads_path,
           params: { file: image_upload },
           headers: { "Authorization" => "Bearer invalid_key" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with a revoked key" do
      revoked_key = create(:api_key, :revoked, :photos_create, user: user)
      post api_uploads_path,
           params: { file: image_upload },
           headers: { "Authorization" => "Bearer #{revoked_key.key}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an expired key" do
      expired_key = create(:api_key, :expired, :photos_create, user: user)
      post api_uploads_path,
           params: { file: image_upload },
           headers: { "Authorization" => "Bearer #{expired_key.key}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates an upload in the given gallery" do
      expect {
        post api_uploads_path,
             params: { file: image_upload, gallery_id: target_gallery.id, title: "Beach", caption: "Sandy" },
             headers: photos_headers
      }.to change { target_gallery.uploads.count }.by(1)

      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["upload"]["gallery"]).to eq("Holiday 1994")
      expect(json["upload"]["short_code"]).to be_present
      expect(json["upload"]["url"]).to include(json["upload"]["short_code"])

      upload = Upload.find(json["upload"]["id"])
      expect(upload.user).to eq(user)
      expect(upload.title).to eq("Beach")
      expect(upload.caption).to eq("Sandy")
      expect(upload.file).to be_attached
    end

    it "enqueues ProcessMediaJob for the new upload" do
      expect {
        post api_uploads_path,
             params: { file: image_upload, gallery_id: target_gallery.id },
             headers: photos_headers
      }.to have_enqueued_job(ProcessMediaJob)
    end

    it "allows an admin scoped key to create uploads" do
      post api_uploads_path,
           params: { file: image_upload, gallery_id: target_gallery.id },
           headers: auth_headers

      expect(response).to have_http_status(:created)
    end

    it "returns 422 when no file is given" do
      post api_uploads_path, params: { gallery_id: target_gallery.id }, headers: photos_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to eq([ "File is required" ])
    end

    it "returns 422 for a non-image file" do
      post api_uploads_path,
           params: { file: fixture_file_upload("test_document.txt", "text/plain"), gallery_id: target_gallery.id },
           headers: photos_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"].join).to match(/image or video/)
      expect(target_gallery.uploads.count).to eq(0)
    end

    it "returns 422 for an oversized file" do
      stub_const("Upload::MAX_FILE_SIZE", 10)

      post api_uploads_path,
           params: { file: image_upload, gallery_id: target_gallery.id },
           headers: photos_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"].join).to match(/too large/)
    end

    describe "gallery resolution" do
      it "returns 403 when gallery_id belongs to another user" do
        other_gallery = create(:gallery)

        post api_uploads_path,
             params: { file: image_upload, gallery_id: other_gallery.id },
             headers: photos_headers

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)["error"]).to eq("Forbidden")
        expect(other_gallery.uploads.count).to eq(0)
      end

      it "returns 403 when gallery_id does not exist" do
        post api_uploads_path,
             params: { file: image_upload, gallery_id: 999999 },
             headers: photos_headers

        expect(response).to have_http_status(:forbidden)
      end

      it "creates the gallery named by gallery_name, then reuses it case-insensitively" do
        expect {
          post api_uploads_path,
               params: { file: image_upload, gallery_name: "Summer 1987" },
               headers: photos_headers
        }.to change { user.galleries.count }.by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["upload"]["gallery"]).to eq("Summer 1987")

        expect {
          post api_uploads_path,
               params: { file: fixture_file_upload("test_image_with_exif.jpg", "image/jpeg"), gallery_name: "  summer 1987 " },
               headers: photos_headers
        }.not_to change { user.galleries.count }

        expect(JSON.parse(response.body)["upload"]["gallery"]).to eq("Summer 1987")
      end

      it "falls back to a single Shortcuts Inbox gallery" do
        expect {
          post api_uploads_path, params: { file: image_upload }, headers: photos_headers
        }.to change { user.galleries.where(title: "Shortcuts Inbox").count }.by(1)

        expect(JSON.parse(response.body)["upload"]["gallery"]).to eq("Shortcuts Inbox")

        expect {
          post api_uploads_path,
               params: { file: fixture_file_upload("test_image_with_exif.jpg", "image/jpeg") },
               headers: photos_headers
        }.not_to change { user.galleries.count }

        expect(response).to have_http_status(:created)
      end

      it "prefers gallery_id over gallery_name" do
        post api_uploads_path,
             params: { file: image_upload, gallery_id: target_gallery.id, gallery_name: "Ignored" },
             headers: photos_headers

        expect(JSON.parse(response.body)["upload"]["gallery"]).to eq("Holiday 1994")
        expect(user.galleries.where(title: "Ignored")).to be_empty
      end
    end

    describe "idempotency" do
      it "returns the existing upload instead of storing the same file twice" do
        post api_uploads_path,
             params: { file: image_upload, gallery_id: target_gallery.id },
             headers: photos_headers

        expect(response).to have_http_status(:created)
        first_id = JSON.parse(response.body)["upload"]["id"]

        expect {
          post api_uploads_path,
               params: { file: image_upload, gallery_id: target_gallery.id },
               headers: photos_headers
        }.not_to change { Upload.count }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["duplicate"]).to be true
        expect(json["success"]).to be true
        expect(json["upload"]["id"]).to eq(first_id)
      end

      it "still creates the upload when the same file lands in a different gallery" do
        other_gallery = create(:gallery, user: user, title: "Elsewhere")

        post api_uploads_path,
             params: { file: image_upload, gallery_id: target_gallery.id },
             headers: photos_headers

        expect {
          post api_uploads_path,
               params: { file: image_upload, gallery_id: other_gallery.id },
               headers: photos_headers
        }.to change { Upload.count }.by(1)

        expect(response).to have_http_status(:created)
      end
    end

    describe "rate limiting" do
      # The test environment uses a null_store, which never counts; swap in a
      # real store for the store object the rate limiter captured at load time
      let(:rate_limit_store) { ActiveSupport::Cache::MemoryStore.new }
      let(:rate_limit_key) { "rate-limit:api/uploads:#{photos_key.id}" }

      before do
        allow(Api::UploadsController.cache_store).to receive(:increment) do |key, amount = 1, **options|
          rate_limit_store.increment(key, amount, **options)
        end
      end

      it "allows requests under the limit" do
        post api_uploads_path,
             params: { file: image_upload, gallery_id: target_gallery.id },
             headers: photos_headers

        expect(response).to have_http_status(:created)
      end

      it "returns 429 once the limit is exceeded" do
        rate_limit_store.write(rate_limit_key, 60, raw: true)

        expect {
          post api_uploads_path,
               params: { file: image_upload, gallery_id: target_gallery.id },
               headers: photos_headers
        }.not_to change { Upload.count }

        expect(response).to have_http_status(:too_many_requests)
        expect(JSON.parse(response.body)["error"]).to eq("Rate limit exceeded")
      end

      it "counts per API key" do
        rate_limit_store.write(rate_limit_key, 60, raw: true)

        post api_uploads_path,
             params: { file: image_upload, gallery_id: target_gallery.id },
             headers: auth_headers

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe "scope enforcement" do
    let(:photos_key) { create(:api_key, :photos_create, user: user) }
    let(:photos_headers) { { "Authorization" => "Bearer #{photos_key.key}" } }

    it "returns 403 from pending for a photos:create key" do
      get pending_api_uploads_path, headers: photos_headers, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to eq("Forbidden")
    end

    it "returns 403 from show for a photos:create key" do
      get api_upload_path(upload_without_analysis.short_code), headers: photos_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 from analysis for a photos:create key" do
      patch analysis_api_upload_path(upload_without_analysis),
            params: { analysis_data: { description: "nope" } },
            headers: photos_headers,
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(upload_without_analysis.reload.analysis_data).to be_nil
    end

    it "still allows a photos:create key to create uploads" do
      post api_uploads_path,
           params: { file: fixture_file_upload("test_image.jpg", "image/jpeg"), gallery_name: "Scoped" },
           headers: photos_headers

      expect(response).to have_http_status(:created)
    end
  end
end
