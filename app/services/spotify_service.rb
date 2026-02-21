class SpotifyService
  BASE_URL = "https://api.spotify.com/v1"
  TOKEN_URL = "https://accounts.spotify.com/api/token"

  def initialize
    @client_id = Rails.application.credentials.dig(:spotify, :client_id)
    @client_secret = Rails.application.credentials.dig(:spotify, :client_secret)
  end

  def configured?
    @client_id.present? && @client_secret.present?
  end

  def search(query, type: "playlist", limit: 10)
    return { error: "Spotify not configured" } unless configured?

    token = fetch_access_token
    return { error: "Failed to authenticate with Spotify" } unless token

    uri = URI("#{BASE_URL}/search")
    uri.query = URI.encode_www_form(q: query, type: type, limit: limit)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      parse_search_results(JSON.parse(response.body), type)
    else
      { error: "Search failed" }
    end
  end

  private

  def fetch_access_token
    # Check cache first
    cached = Rails.cache.read("spotify_access_token")
    return cached if cached

    uri = URI(TOKEN_URL)
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(@client_id, @client_secret)
    request.set_form_data(grant_type: "client_credentials")

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      token = data["access_token"]
      expires_in = data["expires_in"] || 3600

      # Cache token (expire 1 minute early to be safe)
      Rails.cache.write("spotify_access_token", token, expires_in: expires_in - 60)
      token
    end
  end

  def parse_search_results(data, type)
    items_key = "#{type}s" # playlist -> playlists, album -> albums

    items = data.dig(items_key, "items") || []
    {
      results: items.map do |item|
        {
          id: item["id"],
          name: item["name"],
          type: item["type"],
          url: item.dig("external_urls", "spotify"),
          image: item.dig("images", 0, "url"),
          owner: item.dig("owner", "display_name"),
          artist: item.dig("artists", 0, "name"),
          tracks: item["tracks"].is_a?(Hash) ? item.dig("tracks", "total") : nil
        }.compact
      end
    }
  end
end
