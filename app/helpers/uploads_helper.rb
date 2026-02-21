# frozen_string_literal: true

module UploadsHelper
  # Standard variant options - keep in sync with ProcessMediaJob::VARIANTS
  VARIANT_OPTIONS = {
    thumb: { resize_to_fill: [ 400, 400 ] },
    medium: { resize_to_limit: [ 1024, 1024 ] },
    large: { resize_to_limit: [ 2048, 2048 ] }
  }.freeze

  def upload_variant_url(upload, size)
    return nil unless upload.file.attached?

    options = VARIANT_OPTIONS[size.to_sym]
    return url_for(upload.file) unless options

    url_for(upload.file.variant(options))
  end

  def upload_image_data(upload, index: 0)
    return nil unless upload.file.attached?

    {
      id: upload.id,
      index: index,
      title: upload.title,
      caption: upload.caption,
      date_taken: upload.date_taken&.to_s,
      original: url_for(upload.file),
      thumb: upload_variant_url(upload, :thumb),
      medium: upload_variant_url(upload, :medium),
      large: upload_variant_url(upload, :large)
    }
  end
end
