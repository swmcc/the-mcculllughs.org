class Gallery < ApplicationRecord
  belongs_to :user
  belongs_to :cover_upload, class_name: "Upload", optional: true
  has_many :uploads, dependent: :destroy
  has_many :imports, dependent: :nullify

  validates :title, presence: true
  validates :user, presence: true
  validate :cover_upload_belongs_to_gallery

  scope :recent, -> { order(created_at: :desc) }

  def cover_photo
    cover_upload || uploads.first
  end

  private

  def cover_upload_belongs_to_gallery
    return unless cover_upload.present?
    return if cover_upload.gallery_id == id

    errors.add(:cover_upload, "must belong to this gallery")
  end
end
