class UploadsController < ApplicationController
  before_action :set_gallery, only: [ :create ]
  before_action :set_upload, only: [ :destroy ]

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
        format.turbo_stream
      else
        format.html { redirect_to @gallery, alert: "Failed to upload files: #{errors.join(', ')}" }
      end
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

  private

  def set_gallery
    @gallery = Gallery.find(params[:gallery_id])
  end

  def set_upload
    @upload = Upload.find(params[:id])
  end

  def upload_params
    params.require(:upload).permit(:title, :caption, :file)
  end
end
