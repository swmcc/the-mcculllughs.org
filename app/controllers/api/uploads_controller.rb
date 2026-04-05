# frozen_string_literal: true

module Api
  class UploadsController < BaseController
    include UploadsHelper

    def pending
      page = (params[:page] || 1).to_i
      per_page = [ (params[:per_page] || 50).to_i, 100 ].min

      uploads = Upload.where(analysis_data: nil)
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
      params.permit(:analysis_data, embedding: []).tap do |p|
        p[:analysis_data] = params[:analysis_data].permit! if params[:analysis_data].is_a?(ActionController::Parameters)
      end
    end

    def serialize_upload(upload)
      {
        id: upload.id,
        short_code: upload.short_code,
        image_url: upload_variant_url(upload, :large),
        created_at: upload.created_at
      }
    end
  end
end
