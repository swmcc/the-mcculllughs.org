class SlideshowsController < ApplicationController
  include UploadsHelper

  before_action :authenticate_user!

  def index
    @slideshows = if current_user.admin?
      Slideshow.includes(:uploads, :user).order(created_at: :desc)
    else
      current_user.slideshows.includes(:uploads).order(created_at: :desc)
    end
  end

  def show
    @slideshow = if current_user.admin?
      Slideshow.find(params[:id])
    else
      current_user.slideshows.find(params[:id])
    end
    @uploads = @slideshow.uploads

    @images_data = @uploads.select { |u| u.file.attached? }.map.with_index do |u, i|
      {
        id: u.id,
        index: i,
        title: u.title,
        caption: u.caption,
        date_taken: u.date_taken&.to_s,
        is_public: u.is_public,
        short_code: u.short_code,
        original: url_for(u.file),
        thumb: upload_variant_url(u, :thumb),
        medium: upload_variant_url(u, :medium),
        large: upload_variant_url(u, :large)
      }
    end
  end

  def create
    @slideshow = current_user.slideshows.build(slideshow_params)

    # Add uploads from params
    if params[:upload_ids].present?
      params[:upload_ids].each_with_index do |upload_id, index|
        @slideshow.slideshow_uploads.build(upload_id: upload_id, position: index)
      end
    end

    if @slideshow.save
      render json: { id: @slideshow.id, redirect: slideshow_path(@slideshow) }
    else
      render json: { errors: @slideshow.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def edit
    @slideshow = current_user.slideshows.find(params[:id])
  end

  def update
    @slideshow = current_user.slideshows.find(params[:id])
    if @slideshow.update(slideshow_params)
      redirect_to slideshow_path(@slideshow), notice: "Slideshow updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @slideshow = current_user.slideshows.find(params[:id])
    @slideshow.destroy
    redirect_to slideshows_path, notice: "Slideshow deleted"
  end

  private

  def slideshow_params
    params.require(:slideshow).permit(:title, :description, :interval, :audio)
  end
end
