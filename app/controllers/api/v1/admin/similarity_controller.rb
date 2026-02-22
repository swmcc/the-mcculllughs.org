module Api
  module V1
    module Admin
      class SimilarityController < BaseController
        before_action :require_admin_scope!

        def search
          embedding = params[:embedding]
          limit = (params[:limit] || 10).to_i.clamp(1, 100)

          unless embedding.is_a?(Array) && embedding.length == 768
            return render json: {
              error: "Validation Failed",
              message: "Embedding must be an array of 768 floats"
            }, status: :unprocessable_entity
          end

          results = Upload
            .with_embedding
            .nearest_neighbors(:embedding, embedding, distance: :cosine)
            .limit(limit)

          render json: {
            results: results.map do |upload|
              {
                id: upload.id,
                distance: upload.neighbor_distance,
                filename: upload.file.filename.to_s,
                gallery_id: upload.gallery_id
              }
            end
          }
        end
      end
    end
  end
end
