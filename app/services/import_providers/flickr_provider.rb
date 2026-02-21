# frozen_string_literal: true

require "oauth"
require "open-uri"

module ImportProviders
  class FlickrProvider < Base
    FLICKR_SITE = "https://www.flickr.com"
    FLICKR_API_URL = "https://api.flickr.com/services/rest"

    def provider_name
      "flickr"
    end

    def authorize_url(callback_url:, api_key: nil, api_secret: nil)
      # Use provided credentials or fall back to connection credentials
      @temp_api_key = api_key
      @temp_api_secret = api_secret

      request_token = consumer.get_request_token(oauth_callback: callback_url)

      # Store request token in session via the returned hash
      {
        url: request_token.authorize_url(perms: "read"),
        request_token: request_token.token,
        request_secret: request_token.secret
      }
    end

    def exchange_code(params:, callback_url:, api_key: nil, api_secret: nil)
      # Use provided credentials for the exchange
      @temp_api_key = api_key
      @temp_api_secret = api_secret
      @consumer = nil # Reset consumer to use new credentials

      request_token = OAuth::RequestToken.new(
        consumer,
        params[:request_token],
        params[:request_secret]
      )

      access_token = request_token.get_access_token(oauth_verifier: params[:oauth_verifier])

      {
        access_token: access_token.token,
        access_secret: access_token.secret,
        external_user_id: access_token.params[:user_nsid],
        external_username: access_token.params[:username]
      }
    end

    def albums(page: 1)
      response = api_call("flickr.photosets.getList", {
        user_id: connection.external_user_id,
        page: page,
        per_page: 50,
        primary_photo_extras: "url_sq,url_m"
      })

      photosets = response.dig("photosets", "photoset") || []

      {
        albums: photosets.map { |ps| map_album(ps) },
        page: response.dig("photosets", "page").to_i,
        total_pages: response.dig("photosets", "pages").to_i,
        total: response.dig("photosets", "total").to_i
      }
    end

    def album_photos(album_id:, page: 1)
      response = api_call("flickr.photosets.getPhotos", {
        photoset_id: album_id,
        user_id: connection.external_user_id,
        page: page,
        per_page: 100,
        extras: "url_o,url_l,url_c,url_m,url_sq,date_taken,geo,tags,description"
      })

      photos = response.dig("photoset", "photo") || []

      {
        photos: photos,
        page: response.dig("photoset", "page").to_i,
        total_pages: response.dig("photoset", "pages").to_i,
        total: response.dig("photoset", "total").to_i
      }
    end

    def best_download_url(photo_data)
      # Prefer largest available: original > large > medium
      photo_data["url_o"] || photo_data["url_l"] || photo_data["url_c"] || photo_data["url_m"]
    end

    def map_to_upload_attrs(photo_data)
      {
        external_photo_id: photo_data["id"],
        title: extract_title(photo_data),
        caption: extract_description(photo_data),
        date_taken: parse_date_taken(photo_data),
        import_metadata: {
          provider: "flickr",
          flickr_id: photo_data["id"],
          tags: extract_tags(photo_data),
          geo: extract_geo(photo_data),
          urls: extract_urls(photo_data),
          raw: photo_data
        }
      }
    end

    private

    def consumer
      key = @temp_api_key || connection&.api_key
      secret = @temp_api_secret || connection&.api_secret

      raise "Flickr API credentials not configured" unless key.present? && secret.present?

      @consumer ||= OAuth::Consumer.new(
        key,
        secret,
        site: FLICKR_SITE,
        request_token_path: "/services/oauth/request_token",
        access_token_path: "/services/oauth/access_token",
        authorize_path: "/services/oauth/authorize"
      )
    end

    def access_token
      @access_token ||= OAuth::AccessToken.new(
        consumer,
        connection.access_token,
        connection.access_secret
      )
    end

    def api_call(method, params = {})
      query_params = params.merge(
        method: method,
        format: "json",
        nojsoncallback: 1
      )

      response = access_token.get("#{FLICKR_API_URL}?#{query_params.to_query}")
      JSON.parse(response.body)
    end

    def map_album(photoset)
      {
        id: photoset["id"],
        title: photoset.dig("title", "_content") || photoset["title"],
        description: photoset.dig("description", "_content"),
        photo_count: photoset["photos"].to_i,
        cover_url: photoset.dig("primary_photo_extras", "url_m") || photoset["url_m"]
      }
    end

    def extract_title(photo_data)
      title = photo_data["title"]
      title = title["_content"] if title.is_a?(Hash)
      title.presence || "Untitled"
    end

    def extract_description(photo_data)
      desc = photo_data["description"]
      desc = desc["_content"] if desc.is_a?(Hash)
      desc.presence
    end

    def parse_date_taken(photo_data)
      return nil unless photo_data["datetaken"].present?
      DateTime.parse(photo_data["datetaken"])
    rescue ArgumentError
      nil
    end

    def extract_tags(photo_data)
      return [] unless photo_data["tags"].present?

      if photo_data["tags"].is_a?(String)
        photo_data["tags"].split.map(&:strip)
      elsif photo_data["tags"].is_a?(Hash) && photo_data["tags"]["tag"]
        Array(photo_data["tags"]["tag"]).map { |t| t["_content"] || t["raw"] }
      else
        []
      end
    end

    def extract_geo(photo_data)
      return nil unless photo_data["latitude"].present? && photo_data["latitude"].to_f.nonzero?

      {
        latitude: photo_data["latitude"].to_f,
        longitude: photo_data["longitude"].to_f,
        accuracy: photo_data["accuracy"].to_i
      }
    end

    def extract_urls(photo_data)
      {
        original: photo_data["url_o"],
        large: photo_data["url_l"],
        medium: photo_data["url_c"] || photo_data["url_m"],
        thumbnail: photo_data["url_sq"]
      }.compact
    end
  end
end
