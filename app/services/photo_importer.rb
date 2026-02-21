# frozen_string_literal: true

class PhotoImporter
  attr_reader :import, :photo_data, :provider

  def initialize(import:, photo_data:, provider:)
    @import = import
    @photo_data = photo_data
    @provider = provider
  end

  def call
    return { success: false, error: "Already imported" } if already_imported?

    upload = build_upload
    download_and_attach_file(upload)

    if upload.save
      { success: true, upload: upload }
    else
      { success: false, error: upload.errors.full_messages.join(", ") }
    end
  rescue StandardError => e
    Rails.logger.error "PhotoImporter failed for #{photo_data['id']}: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def already_imported?
    Upload.exists?(
      external_photo_id: photo_data["id"],
      user_id: import.user_id
    )
  end

  def build_upload
    attrs = provider.map_to_upload_attrs(photo_data)

    Upload.new(
      user: import.user,
      gallery: import.gallery,
      import: import,
      external_photo_id: attrs[:external_photo_id],
      title: attrs[:title],
      caption: attrs[:caption],
      date_taken: attrs[:date_taken],
      import_metadata: attrs[:import_metadata]
    )
  end

  def download_and_attach_file(upload)
    downloaded_file = provider.download_photo(photo_data)
    filename = generate_filename

    upload.file.attach(
      io: downloaded_file,
      filename: filename,
      content_type: detect_content_type(downloaded_file)
    )
  end

  def generate_filename
    ext = photo_data["originalformat"] || "jpg"
    "#{import.provider}_#{photo_data['id']}.#{ext}"
  end

  def detect_content_type(file)
    # Default to JPEG for photos
    "image/jpeg"
  end
end
