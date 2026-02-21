class PublicPhotosController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_upload

  # GET /t/:short_code - just the thumbnail image
  def thumbnail
    raise ActiveRecord::RecordNotFound unless @upload.is_public?

    redirect_to url_for(@upload.file.variant(resize_to_fill: [ 80, 80 ])), allow_other_host: true
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
      render json: { success: false, errors: @upload.errors.full_messages }, status: :unprocessable_entity
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
