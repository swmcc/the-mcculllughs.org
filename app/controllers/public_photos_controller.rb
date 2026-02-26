class PublicPhotosController < ApplicationController
  skip_before_action :authenticate_user!
  layout "public"
  before_action :set_upload

  # GET /t/:short_code - just the thumbnail image
  def thumbnail
    raise ActiveRecord::RecordNotFound unless @upload.is_public?

    # Use WebP variant if browser supports it, otherwise use standard thumb
    variant_options = if request.accepts.any? { |t| t.to_s.include?("webp") }
      ProcessMediaJob::WEBP_VARIANTS[:thumb]
    else
      ProcessMediaJob::VARIANTS[:thumb]
    end

    # Cache the redirect for 1 year (thumbnail URLs are immutable)
    expires_in 1.year, public: true

    redirect_to rails_representation_url(@upload.file.variant(variant_options).processed), allow_other_host: true
  end

  # GET /p/:short_code - full photo page
  def show
    unless @upload.is_public? || can_edit?
      raise ActiveRecord::RecordNotFound
    end
  end

  def update
    unless can_edit?
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    if @upload.update(upload_params)
      render json: { success: true, is_public: @upload.is_public }
    else
      render json: { success: false, errors: @upload.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def set_upload
    @upload = Upload.find_by!(short_code: params[:short_code])
  end

  def can_edit?
    current_user&.admin? || @upload.gallery.user == current_user
  end
  helper_method :can_edit?

  def upload_params
    params.require(:upload).permit(:is_public)
  end
end
