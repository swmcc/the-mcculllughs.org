class UploadsController < ApplicationController
  before_action :set_gallery, only: [ :create ]
  before_action :set_upload, only: [ :destroy ]

  def create
    @upload = @gallery.uploads.build(upload_params)
    @upload.user = current_user

    respond_to do |format|
      if @upload.save
        format.html { redirect_to @gallery, notice: "Upload was successfully created." }
        format.turbo_stream
      else
        format.html { redirect_to @gallery, alert: "Failed to upload file." }
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
