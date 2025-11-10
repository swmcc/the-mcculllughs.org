class ProcessMediaJob < ApplicationJob
  queue_as :default

  def perform(upload_id)
    upload = Upload.find(upload_id)
    return unless upload.file.attached?

    # Generate thumbnail based on content type
    if upload.file.content_type.start_with?("image/")
      process_image(upload)
    elsif upload.file.content_type.start_with?("video/")
      process_video(upload)
    end
  end

  private

  def process_image(upload)
    # Generate thumbnail for images
    upload.file.open do |file|
      thumbnail = ImageProcessing::MiniMagick
        .source(file)
        .resize_to_limit(400, 400)
        .call

      upload.thumbnail.attach(
        io: File.open(thumbnail.path),
        filename: "thumb_#{upload.file.filename}",
        content_type: upload.file.content_type
      )
    end
  end

  def process_video(upload)
    # For videos, we could extract a frame for thumbnail
    # This is a placeholder - you'd need ffmpeg or similar
    # For now, just log that we'd process it
    Rails.logger.info "Video processing for upload #{upload.id} would happen here"
  end
end
