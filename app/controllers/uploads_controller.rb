class UploadsController < ApplicationController
  before_action :set_gallery, only: [ :create ]
  before_action :set_upload, only: [ :update, :destroy, :set_cover ]
  before_action :authorize_edit!, only: [ :update ]

  def create
    # Handle multiple file uploads
    files = params[:upload][:file]
    files = [ files ] unless files.is_a?(Array)

    success_count = 0
    errors = []

    files.each do |file|
      next if file.blank?

      upload = @gallery.uploads.build(
        file: file,
        title: params[:upload][:title],
        caption: params[:upload][:caption],
        user: current_user
      )

      if upload.save
        success_count += 1
      else
        errors << upload.errors.full_messages.join(", ")
      end
    end

    respond_to do |format|
      if success_count > 0
        message = "#{success_count} #{success_count == 1 ? 'photo' : 'photos'} uploaded successfully"
        message += ". #{errors.length} failed." if errors.any?
        format.html { redirect_to @gallery, notice: message }
        format.turbo_stream { head :ok }
        format.json { render json: { success: true, message: message }, status: :ok }
      else
        format.html { redirect_to @gallery, alert: "Failed to upload files: #{errors.join(', ')}" }
        format.turbo_stream { head :unprocessable_entity }
        format.json { render json: { success: false, errors: errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @upload.update(upload_params)
      render json: {
        success: true,
        title: @upload.title,
        caption: @upload.caption,
        date_taken: @upload.date_taken&.to_s,
        is_public: @upload.is_public,
        short_code: @upload.short_code
      }
    else
      render json: { success: false, errors: @upload.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    gallery = @upload.gallery

    @upload.destroy

    respond_to do |format|
      format.html { redirect_to gallery, notice: "Upload was successfully deleted." }
      format.turbo_stream
    end
  end

  def set_cover
    @gallery = @upload.gallery
    @previous_cover = @gallery.cover_upload

    @gallery.update!(cover_upload: @upload)

    respond_to do |format|
      format.html { redirect_to @gallery, notice: "Cover photo updated." }
      format.turbo_stream
    end
  end

  private

  def authorize_edit!
    unless current_user&.admin? || @upload.gallery.user == current_user
      render json: { error: "Not authorized" }, status: :forbidden
    end
  end

  def set_gallery
    @gallery = Gallery.find(params[:gallery_id])
  end

  def set_upload
    @upload = Upload.find(params[:id])
  end

  def upload_params
    params.require(:upload).permit(:title, :caption, :file, :date_taken, :is_public)
  end
end
