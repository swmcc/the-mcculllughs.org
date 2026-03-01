# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @stats = {
      galleries: current_user.admin? ? Gallery.count : current_user.galleries.count,
      uploads: current_user.admin? ? Upload.count : current_user.uploads.count,
      slideshows: current_user.admin? ? Slideshow.count : current_user.slideshows.count,
      public_photos: current_user.admin? ? Upload.where(is_public: true).count : current_user.uploads.where(is_public: true).count
    }

    @recent_galleries = (current_user.admin? ? Gallery : current_user.galleries)
                          .includes(:user, cover_upload: { file_attachment: :blob })
                          .order(updated_at: :desc)
                          .limit(4)

    @recent_uploads = (current_user.admin? ? Upload : current_user.uploads)
                        .includes(:user, file_attachment: :blob)
                        .order(created_at: :desc)
                        .limit(8)
  end
end
