# frozen_string_literal: true

class ImportAlbumJob < ApplicationJob
  queue_as :imports

  # Rate limiting: be conservative to avoid hitting API limits
  PHOTO_DELAY = 0.5.seconds

  def perform(import_id)
    @import = Import.find_by(id: import_id)
    return unless @import
    return if @import.completed? || @import.failed?

    @import.start!
    @provider = build_provider

    import_all_photos

    @import.complete!
  rescue StandardError => e
    Rails.logger.error "ImportAlbumJob failed for import #{import_id}: #{e.message}"
    @import&.fail!(e.message)
    raise
  end

  private

  def build_provider
    case @import.provider
    when "flickr"
      ImportProviders::FlickrProvider.new(user: @import.user)
    when "google"
      ImportProviders::GoogleProvider.new(user: @import.user)
    when "facebook"
      ImportProviders::FacebookProvider.new(user: @import.user)
    else
      raise "Unknown provider: #{@import.provider}"
    end
  end

  def import_all_photos
    page = 1

    loop do
      result = @provider.album_photos(album_id: @import.external_album_id, page: page)

      break if result[:photos].blank?

      # Update total on first page
      @import.update!(total_photos: result[:total]) if page == 1

      result[:photos].each do |photo_data|
        import_single_photo(photo_data)
        sleep(PHOTO_DELAY) # Rate limiting
      end

      page += 1
      break if page > result[:total_pages]
    end
  end

  def import_single_photo(photo_data)
    result = PhotoImporter.new(
      import: @import,
      photo_data: photo_data,
      provider: @provider
    ).call

    if result[:success]
      @import.increment_imported!
      Rails.logger.info "Imported photo #{photo_data['id']} for import #{@import.id}"
    else
      @import.increment_failed!
      Rails.logger.warn "Failed to import photo #{photo_data['id']}: #{result[:error]}"
    end
  end
end
