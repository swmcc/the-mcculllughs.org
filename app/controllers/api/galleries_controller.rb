# frozen_string_literal: true

module Api
  class GalleriesController < BaseController
    skip_before_action :require_admin_scope!, only: [ :index ]
    before_action :require_photos_create_scope!, only: [ :index ]

    def index
      galleries = current_user.galleries
                              .left_joins(:uploads)
                              .group("galleries.id")
                              .order(:title)
                              .select("galleries.*, COUNT(uploads.id) AS uploads_count")

      render json: {
        galleries: galleries.map { |gallery| serialize_gallery(gallery) }
      }
    end

    private

    def require_photos_create_scope!
      require_scope!("photos:create")
    end

    def serialize_gallery(gallery)
      {
        id: gallery.id,
        title: gallery.title,
        uploads_count: gallery.uploads_count.to_i
      }
    end
  end
end
