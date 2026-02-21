# frozen_string_literal: true

class ImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_provider, only: [ :connect, :callback, :disconnect, :albums, :import ]
  before_action :ensure_connected, only: [ :albums, :import ]

  PROVIDERS = {
    "flickr" => ImportProviders::FlickrProvider
  }.freeze

  # GET /imports
  def index
    @imports = current_user.imports.recent.includes(:gallery)
    @connections = current_user.external_connections
  end

  # GET /imports/providers
  def providers
    @connections = current_user.external_connections.index_by(&:provider)
  end

  # GET /imports/:provider/connect
  def connect
    result = @provider_service.authorize_url(callback_url: callback_imports_url(@provider_name))

    # Store request token in session for OAuth 1.0a
    if result[:request_token]
      session[:oauth_request_token] = result[:request_token]
      session[:oauth_request_secret] = result[:request_secret]
    end

    redirect_to result[:url], allow_other_host: true
  end

  # GET /imports/:provider/callback
  def callback
    params_for_exchange = {
      oauth_verifier: params[:oauth_verifier],
      code: params[:code],
      request_token: session.delete(:oauth_request_token),
      request_secret: session.delete(:oauth_request_secret)
    }

    result = @provider_service.exchange_code(
      params: params_for_exchange,
      callback_url: callback_imports_url(@provider_name)
    )

    connection = current_user.external_connections.find_or_initialize_by(provider: @provider_name)
    connection.update!(
      access_token: result[:access_token],
      access_secret: result[:access_secret],
      refresh_token: result[:refresh_token],
      token_expires_at: result[:token_expires_at],
      external_user_id: result[:external_user_id],
      external_username: result[:external_username],
      connected_at: Time.current
    )

    redirect_to albums_imports_path(@provider_name), notice: "Connected to #{@provider_name.titleize} as #{result[:external_username]}"
  rescue StandardError => e
    Rails.logger.error "OAuth callback failed: #{e.message}"
    redirect_to providers_imports_path, alert: "Failed to connect: #{e.message}"
  end

  # DELETE /imports/:provider/disconnect
  def disconnect
    current_user.connection_for(@provider_name)&.disconnect!
    redirect_to providers_imports_path, notice: "Disconnected from #{@provider_name.titleize}"
  end

  # GET /imports/:provider/albums
  def albums
    page = (params[:page] || 1).to_i
    result = @provider_service.albums(page: page)

    @albums = result[:albums]
    @page = result[:page]
    @total_pages = result[:total_pages]
    @existing_imports = current_user.imports
                                    .where(provider: @provider_name)
                                    .pluck(:external_album_id)
  end

  # POST /imports/:provider/import
  def import
    album_id = params[:album_id]
    album_title = params[:album_title]

    # Check for existing import
    if current_user.imports.exists?(provider: @provider_name, external_album_id: album_id)
      redirect_to albums_imports_path(@provider_name), alert: "This album has already been imported"
      return
    end

    # Create gallery for this import
    gallery = current_user.galleries.create!(
      title: album_title.presence || "#{@provider_name.titleize} Import #{Time.current.strftime('%Y-%m-%d %H:%M')}"
    )

    # Create import record
    import = current_user.imports.create!(
      provider: @provider_name,
      external_album_id: album_id,
      album_title: album_title,
      gallery: gallery,
      external_connection: current_user.connection_for(@provider_name),
      status: "pending"
    )

    # Queue the import job
    ImportAlbumJob.perform_later(import.id)

    redirect_to status_import_path(import), notice: "Import started! Photos will appear in your new gallery."
  end

  # GET /imports/:id/status
  def status
    @import = current_user.imports.find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def set_provider
    @provider_name = params[:provider]

    unless PROVIDERS.key?(@provider_name)
      redirect_to providers_imports_path, alert: "Unknown provider: #{@provider_name}"
      return
    end

    @provider_service = PROVIDERS[@provider_name].new(user: current_user)
  end

  def ensure_connected
    unless current_user.connected_to?(@provider_name)
      redirect_to connect_imports_path(@provider_name)
    end
  end
end
