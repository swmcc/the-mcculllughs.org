class GalleriesController < ApplicationController
  before_action :set_gallery, only: [ :show, :edit, :update, :destroy ]

  def index
    @galleries = Gallery.includes(:user).recent
  end

  def show
    @uploads = @gallery.uploads.recent
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

  def gallery_params
    params.require(:gallery).permit(:title, :description)
  end
end
