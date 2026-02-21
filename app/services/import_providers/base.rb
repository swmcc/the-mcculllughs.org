# frozen_string_literal: true

module ImportProviders
  class Base
    attr_reader :user, :connection

    def initialize(user:)
      @user = user
      @connection = user.connection_for(provider_name)
    end

    def provider_name
      raise NotImplementedError, "Subclasses must implement #provider_name"
    end

    def display_name
      provider_name.titleize
    end

    def connected?
      connection&.connected?
    end

    # Generate OAuth authorization URL
    def authorize_url(callback_url:)
      raise NotImplementedError, "Subclasses must implement #authorize_url"
    end

    # Exchange authorization code/verifier for access token
    def exchange_code(params:, callback_url:)
      raise NotImplementedError, "Subclasses must implement #exchange_code"
    end

    # Refresh expired token (OAuth 2.0 only)
    def refresh_token!
      # Default no-op for OAuth 1.0a
    end

    # List user's albums
    def albums(page: 1)
      raise NotImplementedError, "Subclasses must implement #albums"
    end

    # List photos in an album
    def album_photos(album_id:, page: 1)
      raise NotImplementedError, "Subclasses must implement #album_photos"
    end

    # Download photo and return IO object
    def download_photo(photo_data)
      url = best_download_url(photo_data)
      raise "No download URL available" unless url

      URI.parse(url).open
    end

    # Extract the best download URL from photo data
    def best_download_url(photo_data)
      raise NotImplementedError, "Subclasses must implement #best_download_url"
    end

    # Map provider photo data to upload attributes
    def map_to_upload_attrs(photo_data)
      raise NotImplementedError, "Subclasses must implement #map_to_upload_attrs"
    end

    protected

    def credentials
      Rails.application.credentials.dig(provider_name.to_sym)
    end
  end
end
