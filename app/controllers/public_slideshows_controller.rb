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
        title: u.title,
        caption: u.caption,
        date_taken: u.date_taken&.to_s,
        original: url_for(u.file),
        thumb: upload_variant_url(u, :thumb),
        medium: upload_variant_url(u, :medium),
        large: upload_variant_url(u, :large),
        thumb_webp: upload_variant_url(u, :thumb, format: :webp),
        medium_webp: upload_variant_url(u, :medium, format: :webp),
        large_webp: upload_variant_url(u, :large, format: :webp)
      }
    end

    render "slideshows/show"
  end
end
