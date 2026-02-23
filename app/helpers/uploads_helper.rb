# frozen_string_literal: true

module UploadsHelper
  def upload_variant_url(upload, size)
    return nil unless upload.file.attached?

    options = ProcessMediaJob::VARIANTS[size.to_sym]
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
