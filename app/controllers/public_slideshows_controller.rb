class PublicSlideshowsController < ApplicationController
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
        large: upload_variant_url(u, :large)
      }
    end

    render "slideshows/show"
  end

  private

  def upload_variant_url(upload, variant)
    return "" unless upload.file.attached?

    case variant
    when :thumb
      url_for(upload.file.variant(resize_to_fill: [ 300, 300 ]))
    when :medium
      url_for(upload.file.variant(resize_to_limit: [ 800, 800 ]))
    when :large
      url_for(upload.file.variant(resize_to_limit: [ 1600, 1600 ]))
    else
      url_for(upload.file)
    end
  rescue
    ""
  end
end
