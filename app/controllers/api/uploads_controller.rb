# frozen_string_literal: true

module Api
  class UploadsController < BaseController
    include UploadsHelper

    DEFAULT_GALLERY_TITLE = "Shortcuts Inbox"

    # Uploading only needs the photos:create scope, everything else stays admin-only
    skip_before_action :require_admin_scope!, only: [ :create ]
    before_action :require_photos_create_scope!, only: [ :create ]

    # Declared here (not in BaseController) so authentication runs first and
    # current_api_key is available to the identity lambda
    rate_limit to: 60,
               within: 1.minute,
               only: :create,
               by: -> { current_api_key.id },
               with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

    def pending
      page = (params[:page] || 1).to_i
      per_page = [ (params[:per_page] || 50).to_i, 100 ].min

      uploads = Upload.where(analysis_data: nil)
                      .includes(:gallery)
                      .order(created_at: :asc)
                      .offset((page - 1) * per_page)
                      .limit(per_page)
                      .with_file

      total_count = Upload.where(analysis_data: nil).count

      render json: {
        uploads: uploads.map { |upload| serialize_upload(upload) },
        total: total_count,
        page: page,
        per_page: per_page
      }
    end

    def show
      upload = Upload.includes(:gallery).find_by!(short_code: params[:id])
      render json: { upload: serialize_upload(upload) }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Upload not found" }, status: :not_found
    end

    def analysis
      upload = Upload.find(params[:id])

      if upload.update(analysis_params)
        render json: { success: true, id: upload.id }
      else
        render json: { success: false, errors: upload.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def create
      return render_missing_file if params[:file].blank?

      gallery = resolve_gallery
      return if performed?

      existing = duplicate_upload(gallery)
      return render json: serialize_created(existing).merge(duplicate: true), status: :ok if existing

      upload = current_user.uploads.build(
        gallery: gallery,
        title: params[:title],
        caption: params[:caption],
        file: params[:file]
      )

      if upload.save
        render json: serialize_created(upload), status: :created
      else
        render json: { success: false, errors: upload.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def require_photos_create_scope!
      require_scope!("photos:create")
    end

    def render_missing_file
      render json: { success: false, errors: [ "File is required" ] }, status: :unprocessable_entity
    end

    # gallery_id wins over gallery_name; falling back to the default inbox gallery.
    # Renders 403 (and returns nil) when gallery_id is not one of the key owner's galleries.
    def resolve_gallery
      if params[:gallery_id].present?
        gallery = current_user.galleries.find_by(id: params[:gallery_id])
        render json: { error: "Forbidden" }, status: :forbidden if gallery.nil?
        gallery
      elsif params[:gallery_name].present?
        find_or_create_gallery(params[:gallery_name].strip)
      else
        find_or_create_gallery(DEFAULT_GALLERY_TITLE)
      end
    end

    def find_or_create_gallery(title)
      current_user.galleries.where("LOWER(title) = ?", title.downcase).first ||
        current_user.galleries.create!(title: title)
    end

    # Idempotency: the same bytes in the same gallery are only stored once.
    # Matches how Active Storage computes active_storage_blobs.checksum.
    def duplicate_upload(gallery)
      checksum = uploaded_file_checksum(params[:file])
      return nil if checksum.nil?

      current_user.uploads
                  .where(gallery: gallery)
                  .joins(file_attachment: :blob)
                  .find_by(active_storage_blobs: { checksum: checksum })
    end

    def uploaded_file_checksum(file)
      return nil unless file.respond_to?(:tempfile)

      OpenSSL::Digest::MD5.file(file.tempfile.path).base64digest
    end

    def serialize_created(upload)
      {
        success: true,
        upload: {
          id: upload.id,
          short_code: upload.short_code,
          gallery: upload.gallery.title,
          url: upload.public_url
        }
      }
    end

    def analysis_params
      permitted = {}

      # Explicitly permit full Indexatron analysis schema
      if params[:analysis_data].present?
        permitted[:analysis_data] = params.require(:analysis_data).permit(
          :description,
          :mood,
          :filename,
          :analyzed_at,
          :model_used,
          location: [ :setting, :type, :specific ],
          era: [ :decade, :confidence, :reasoning ],
          people: [ :name, :description, :estimated_age, :position ],
          categories: [],
          colors: [],
          objects: []
        )
      end

      # Permit embedding as array of floats
      permitted[:embedding] = params[:embedding] if params[:embedding].is_a?(Array)

      permitted
    end

    def serialize_upload(upload)
      {
        id: upload.id,
        short_code: upload.short_code,
        image_url: upload_variant_url(upload, :medium),  # 1024px is enough for AI analysis
        created_at: upload.created_at,
        # Metadata for AI context
        title: upload.title,
        caption: upload.caption,
        date_taken: upload.date_taken,
        gallery_name: upload.gallery&.title,
        gallery_description: upload.gallery&.description
      }
    end
  end
end
