class Upload < ApplicationRecord
  belongs_to :user
  belongs_to :gallery
  belongs_to :import, optional: true

  # Active Storage attachments
  has_one_attached :file
  has_one_attached :thumbnail

  # Callbacks
  before_validation :generate_short_code, on: :create
  after_commit :process_media, on: :create

  # Validations
  validates :file, presence: true
  validates :user, presence: true
  validates :gallery, presence: true
  validates :short_code, presence: true, uniqueness: true

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
end
