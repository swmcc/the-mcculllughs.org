class PublicSlideshowsController < ApplicationController
  include UploadsHelper

  skip_before_action :authenticate_user!

  def show
    @slideshow = Slideshow.find_by!(short_code: params[:short_code])
    @slideshow.increment!(:view_count)
    @uploads = @slideshow.uploads

    @images_data = @uploads.select { |u| u.file.attached? }.map.with_index do |u, i|
      {
        id: u.id,
        index: i,
        short_code: u.short_code,
        title: u.title,
        caption: u.caption,
        date_taken: u.date_taken&.to_s,
        original: url_for(u.file),
        thumb: upload_variant_url(u, :thumb),
        medium: upload_variant_url(u, :medium),
        large: upload_variant_url(u, :large),
        thumb_webp: upload_variant_url(u, :thumb, format: :webp),
        medium_webp: upload_variant_url(u, :medium, format: :webp),
        large_webp: upload_variant_url(u, :large, format: :webp),
        public_url: public_photo_url(u.short_code)
      }
    end

    respond_to do |format|
      format.html { render "slideshows/show" }
      format.json { render json: { title: @slideshow.title, images: @images_data } }
    end
  end
end
