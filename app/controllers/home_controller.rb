class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    if user_signed_in?
      redirect_to galleries_path
    else
      @public_photos = Upload.publicly_visible
                             .includes(file_attachment: :blob)
                             .order("RANDOM()")
                             .limit(200)
      render layout: "landing"
    end
  end
end
