# frozen_string_literal: true

module UploadsHelper
  def upload_variant_url(upload, size, format: nil)
    return nil unless upload.file.attached?

    variants = format == :webp ? ProcessMediaJob::WEBP_VARIANTS : ProcessMediaJob::VARIANTS
    options = variants[size.to_sym]
    return url_for(upload.file) unless options

    url_for(upload.file.variant(options))
  end

  # Renders a <picture> element with WebP source and fallback
  def upload_picture_tag(upload, size, **html_options)
    return nil unless upload.file.attached?

    webp_url = upload_variant_url(upload, size, format: :webp)
    fallback_url = upload_variant_url(upload, size)

    content_tag(:picture) do
      safe_join([
        tag(:source, srcset: webp_url, type: "image/webp"),
        image_tag(fallback_url, **html_options)
      ])
    end
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
      large: upload_variant_url(upload, :large),
      thumb_webp: upload_variant_url(upload, :thumb, format: :webp),
      medium_webp: upload_variant_url(upload, :medium, format: :webp),
      large_webp: upload_variant_url(upload, :large, format: :webp)
    }
  end
end
