module Api
  module V1
    module Admin
      class PhotosController < BaseController
        before_action :require_admin_scope!
        before_action :set_upload, only: [ :show, :download, :analysis, :analysis_failed ]

        def index
          uploads = Upload.images

          case params[:status]
          when "pending"
            uploads = uploads.analysis_pending
          when "processing"
            uploads = uploads.analysis_processing
          when "completed"
            uploads = uploads.analysis_completed
          when "failed"
            uploads = uploads.analysis_failed
          end

          uploads = uploads.includes(:gallery).order(created_at: :asc).limit(params[:limit] || 50)

          render json: {
            photos: uploads.map { |u| photo_json(u) },
            meta: {
              total: Upload.images.count,
              pending: Upload.needs_analysis.count,
              processing: Upload.analysis_processing.count,
              completed: Upload.analysis_completed.count,
              failed: Upload.analysis_failed.count
            }
          }
        end

        def show
          render json: { photo: photo_json(@upload, include_analysis: true) }
        end

        def download
          if @upload.file.attached?
            redirect_to rails_blob_url(@upload.file, disposition: "attachment"), allow_other_host: true
          else
            render json: { error: "Not Found", message: "File not attached" }, status: :not_found
          end
        end

        def analysis
          @upload.complete_analysis!(
            analysis_params[:analysis],
            analysis_params[:embedding],
            analysis_params[:version]
          )

          render json: { status: "success", photo: photo_json(@upload, include_analysis: true) }
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: "Validation Failed", message: e.message }, status: :unprocessable_entity
        end

        def analysis_failed
          @upload.fail_analysis!(params[:error])

          render json: { status: "failed", photo: photo_json(@upload) }
        end

        private

        def set_upload
          @upload = Upload.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Not Found", message: "Photo not found" }, status: :not_found
        end

        def analysis_params
          params.permit(:version, analysis: {}, embedding: [])
        end

        def photo_json(upload, include_analysis: false)
          json = {
            id: upload.id,
            filename: upload.file.filename.to_s,
            content_type: upload.file.content_type,
            created_at: upload.created_at.iso8601,
            gallery_id: upload.gallery_id,
            gallery_title: upload.gallery.title,
            analysis_status: upload.analysis_status,
            analyzed_at: upload.analyzed_at&.iso8601
          }

          if include_analysis && upload.analyzed?
            json[:ai_analysis] = upload.ai_analysis
            json[:analysis_version] = upload.analysis_version
          end

          if upload.analysis_status == "failed"
            json[:analysis_error] = upload.analysis_error
          end

          json
        end
      end
    end
  end
end
