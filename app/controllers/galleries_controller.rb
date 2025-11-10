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

    respond_to do |format|
      if @gallery.save
        format.html { redirect_to @gallery, notice: "Gallery was successfully created." }
        format.turbo_stream
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @gallery.update(gallery_params)
        format.html { redirect_to @gallery, notice: "Gallery was successfully updated." }
        format.turbo_stream
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @gallery.destroy

    respond_to do |format|
      format.html { redirect_to galleries_path, notice: "Gallery was successfully deleted." }
      format.turbo_stream
    end
  end

  private

  def set_gallery
    @gallery = Gallery.find(params[:id])
  end

  def gallery_params
    params.require(:gallery).permit(:title, :description)
  end
end
