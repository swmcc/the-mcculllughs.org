# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    protect_from_forgery with: :null_session
    skip_before_action :authenticate_user!

    before_action :authenticate_api_key!

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_json

    private

    def authenticate_api_key!
      token = extract_bearer_token
      api_key = ApiKey.active.find_by(key: token)

      if api_key.nil?
        render json: { error: "Unauthorized" }, status: :unauthorized
        return
      end

      @current_api_key = api_key
      @current_user = api_key.user
      api_key.touch_last_used!
    end

    def extract_bearer_token
      auth_header = request.headers["Authorization"]
      return nil unless auth_header.present?

      auth_header.split(" ").last if auth_header.start_with?("Bearer ")
    end

    def current_api_key
      @current_api_key
    end

    def render_not_found_json
      render json: { error: "Not found" }, status: :not_found
    end
  end
end
