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

  ALLOWED_EXTENSIONS = %w[jpg jpeg png gif webp heic heif mp4 mov avi webm].freeze
  EXTENSION_TO_CONTENT_TYPE = {
    "jpg" => "image/jpeg",
    "jpeg" => "image/jpeg",
    "png" => "image/png",
    "gif" => "image/gif",
    "webp" => "image/webp",
    "heic" => "image/heic",
    "heif" => "image/heif",
    "mp4" => "video/mp4",
    "mov" => "video/quicktime",
    "avi" => "video/x-msvideo",
    "webm" => "video/webm"
  }.freeze

  def generate_filename
    raw_ext = photo_data["originalformat"].to_s.downcase.gsub(/[^a-z0-9]/, "")
    ext = ALLOWED_EXTENSIONS.include?(raw_ext) ? raw_ext : "jpg"

    # Sanitize the photo ID to prevent path traversal
    safe_id = photo_data["id"].to_s.gsub(/[^a-zA-Z0-9_-]/, "")
    safe_provider = import.provider.to_s.gsub(/[^a-zA-Z0-9_-]/, "")

    "#{safe_provider}_#{safe_id}.#{ext}"
  end

  def detect_content_type(file)
    raw_ext = photo_data["originalformat"].to_s.downcase.gsub(/[^a-z0-9]/, "")
    EXTENSION_TO_CONTENT_TYPE[raw_ext] || "image/jpeg"
  end
end
