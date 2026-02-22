module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_key!

      private

      def authenticate_api_key!
        @current_api_key = ApiKey.authenticate(bearer_token)

        unless @current_api_key
          render json: { error: "Unauthorized", message: "Invalid or expired API key" }, status: :unauthorized
        end
      end

      def bearer_token
        request.headers["Authorization"]&.gsub(/^Bearer\s+/, "")
      end

      def current_api_key
        @current_api_key
      end

      def require_admin_scope!
        unless current_api_key&.scope == "admin"
          render json: { error: "Forbidden", message: "Admin scope required" }, status: :forbidden
        end
      end
    end
  end
end
