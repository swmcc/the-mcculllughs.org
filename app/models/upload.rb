class Upload < ApplicationRecord
  belongs_to :user
  belongs_to :gallery

  # Active Storage attachments
  has_one_attached :file
  has_one_attached :thumbnail

  # Validations
  validates :file, presence: true
  validates :user, presence: true
  validates :gallery, presence: true

  # Callbacks
  after_commit :process_media, on: :create

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :images, -> { where("uploads.file_content_type LIKE ?", "image/%") }
  scope :videos, -> { where("uploads.file_content_type LIKE ?", "video/%") }

  private

  def process_media
    ProcessMediaJob.perform_later(id) if file.attached?
  end
end
