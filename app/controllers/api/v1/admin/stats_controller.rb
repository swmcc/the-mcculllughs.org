module Api
  module V1
    module Admin
      class StatsController < BaseController
        before_action :require_admin_scope!

        def show
          render json: {
            photos: {
              total: Upload.images.count,
              pending: Upload.needs_analysis.count,
              processing: Upload.analysis_processing.count,
              completed: Upload.analysis_completed.count,
              failed: Upload.analysis_failed.count,
              with_embedding: Upload.with_embedding.count
            },
            galleries: {
              total: Gallery.count
            },
            api_keys: {
              total: ApiKey.count,
              active: ApiKey.active.count
            }
          }
        end
      end
    end
  end
end
