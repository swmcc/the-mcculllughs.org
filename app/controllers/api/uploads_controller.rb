# frozen_string_literal: true

module Api
  class UploadsController < BaseController
    include UploadsHelper

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

    private

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
