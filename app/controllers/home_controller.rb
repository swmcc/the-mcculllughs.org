class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    if user_signed_in?
      redirect_to galleries_path
    else
      @public_photos = Upload.publicly_visible
                             .includes(file_attachment: :blob)
                             .order("RANDOM()")
                             .limit(100)

      # Pre-generate thumbnail URLs to avoid N controller redirects
      @photo_data = @public_photos.map do |photo|
        {
          short_code: photo.short_code,
          thumb_url: url_for(photo.file.variant(ProcessMediaJob::VARIANTS[:thumb]))
        }
      end

      render layout: "landing"
    end
  end
end
