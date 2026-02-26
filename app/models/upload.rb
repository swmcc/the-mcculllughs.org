class Upload < ApplicationRecord
  belongs_to :user
  belongs_to :gallery
  belongs_to :import, optional: true
  has_one :gallery_as_cover, class_name: "Gallery", foreign_key: "cover_upload_id", dependent: :nullify

  # Active Storage attachments
  has_one_attached :file
  has_one_attached :thumbnail

  # Callbacks
  before_validation :generate_short_code, on: :create
  after_commit :process_media, on: :create
  before_destroy :clear_as_cover

  # Allowed content types for uploads
  ALLOWED_CONTENT_TYPES = %w[
    image/png image/jpg image/jpeg image/gif image/webp image/heic image/heif
    video/mp4 video/quicktime video/x-msvideo video/webm
  ].freeze

  MAX_FILE_SIZE = 500.megabytes

  # Validations
  validates :file, presence: true
  validates :user, presence: true
  validates :gallery, presence: true
  validates :short_code, presence: true, uniqueness: true
  validate :acceptable_file

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :images, -> { where("uploads.file_content_type LIKE ?", "image/%") }
  scope :videos, -> { where("uploads.file_content_type LIKE ?", "video/%") }
  scope :publicly_visible, -> { where(is_public: true) }
  scope :from_import, -> { where.not(import_id: nil) }

  # Import helpers
  def imported?
    external_photo_id.present?
  end

  # Cover photo helper
  def cover?
    gallery.cover_upload_id == id
  end

  # Public URL helper
  def public_url
    Rails.application.routes.url_helpers.public_photo_url(short_code, host: Rails.application.config.action_mailer.default_url_options[:host] || "localhost:3000")
  end

  private

  def generate_short_code
    return if short_code.present?

    loop do
      self.short_code = SecureRandom.alphanumeric(6)
      break unless Upload.exists?(short_code: short_code)
    end
  end

  def process_media
    ProcessMediaJob.perform_later(id) if file.attached?
  end

  def clear_as_cover
    gallery.update(cover_upload_id: nil) if cover?
  end

  def acceptable_file
    return unless file.attached?

    unless file.blob.content_type.in?(ALLOWED_CONTENT_TYPES)
      errors.add(:file, "must be an image or video (#{ALLOWED_CONTENT_TYPES.join(', ')})")
    end

    if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, "is too large (maximum is #{MAX_FILE_SIZE / 1.megabyte}MB)")
    end
  end
end
