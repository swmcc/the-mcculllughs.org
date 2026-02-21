class SpotifyController < ApplicationController
  before_action :authenticate_user!

  def search
    query = params[:q].to_s.strip
    type = %w[playlist album track].include?(params[:type]) ? params[:type] : "playlist"

    if query.blank?
      render json: { results: [] }
      return
    end

    service = SpotifyService.new(current_user)

    unless service.configured?
      render json: { error: "Spotify is not configured" }, status: :service_unavailable
      return
    end

    result = service.search(query, type: type)

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result
    end
  end
end
