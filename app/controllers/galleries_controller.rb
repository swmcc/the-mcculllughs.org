class GalleriesController < ApplicationController
  before_action :set_gallery, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_gallery!, only: [ :edit, :update, :destroy ]

  def index
    @galleries = Gallery.includes(:user, cover_upload: { file_attachment: :blob }).recent
  end

  def show
    @uploads = @gallery.uploads.includes(file_attachment: :blob).recent
    @upload = @gallery.uploads.build
  end

  def new
    @gallery = Gallery.new
  end

  def create
    @gallery = current_user.galleries.build(gallery_params)

    if @gallery.save
      redirect_to @gallery, notice: "Gallery was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @gallery.update(gallery_params)
      redirect_to @gallery, notice: "Gallery was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @gallery.destroy
    redirect_to galleries_path, notice: "Gallery was successfully deleted."
  end

  private

  def set_gallery
    @gallery = Gallery.find(params[:id])
  end

  def authorize_gallery!
    unless current_user&.admin? || @gallery.user == current_user
      redirect_to galleries_path, alert: "Not authorized"
    end
  end

  def gallery_params
    params.require(:gallery).permit(:title, :description)
  end
end
