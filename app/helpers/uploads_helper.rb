# frozen_string_literal: true

module UploadsHelper
  def upload_variant_url(upload, size, **_options)
    return nil unless upload.file.attached?

    options = ProcessMediaJob::VARIANTS[size.to_sym]
    return url_for(upload.file) unless options

    url_for(upload.file.variant(options))
  end

  # Renders a <picture> element with WebP source and original fallback
  # Includes lazy loading and async decoding by default for performance
  def upload_picture_tag(upload, size, lazy: true, **html_options)
    return nil unless upload.file.attached?

    webp_url = upload_variant_url(upload, size)
    fallback_url = url_for(upload.file)

    # Add performance attributes by default
    html_options[:loading] ||= "lazy" if lazy
    html_options[:decoding] ||= "async"

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
      large: upload_variant_url(upload, :large)
    }
  end
end
