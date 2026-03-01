# frozen_string_literal: true

class ProcessMediaJob < ApplicationJob
  queue_as :default

  # WebP variant sizes - original file serves as fallback/download
  VARIANTS = {
    thumb: { resize_to_fill: [ 400, 400 ], format: :webp, saver: { quality: 80 } },
    medium: { resize_to_limit: [ 1024, 1024 ], format: :webp, saver: { quality: 80 } },
    large: { resize_to_limit: [ 2048, 2048 ], format: :webp, saver: { quality: 80 } }
  }.freeze

  def perform(upload_id)
    upload = Upload.find_by(id: upload_id)
    return unless upload&.file&.attached?

    if upload.file.content_type.start_with?("image/")
      generate_variants(upload)
    elsif upload.file.content_type.start_with?("video/")
      process_video(upload)
    end
  end

  private

  def generate_variants(upload)
    VARIANTS.each do |name, options|
      upload.file.variant(options).processed
      Rails.logger.info "Generated #{name} variant for upload #{upload.id}"
    rescue StandardError => e
      Rails.logger.error "Failed to generate #{name} variant for upload #{upload.id}: #{e.message}"
    end
  end

  def process_video(upload)
    # For videos, we could extract a frame for thumbnail
    # This is a placeholder - you'd need ffmpeg or similar
    Rails.logger.info "Video processing for upload #{upload.id} would happen here"
  end
end
