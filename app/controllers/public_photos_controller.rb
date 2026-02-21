class PublicPhotosController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @upload = Upload.find_by!(short_code: params[:short_code])

    unless @upload.is_public?
      raise ActiveRecord::RecordNotFound
    end
  end
end
