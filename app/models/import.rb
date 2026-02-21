# frozen_string_literal: true

class Import < ApplicationRecord
  STATUSES = %w[pending in_progress completed failed].freeze
  PROVIDERS = ExternalConnection::PROVIDERS

  belongs_to :user
  belongs_to :gallery, optional: true
  belongs_to :external_connection, optional: true
  has_many :uploads, dependent: :nullify

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :external_album_id, presence: true
  validates :external_album_id, uniqueness: { scope: [ :user_id, :provider ], message: "album already imported" }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[pending in_progress]) }
  scope :for_provider, ->(provider) { where(provider: provider) }

  def pending?
    status == "pending"
  end

  def in_progress?
    status == "in_progress"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def progress_percentage
    return 0 if total_photos.zero?
    ((imported_count + failed_count) * 100.0 / total_photos).round
  end

  def complete?
    imported_count + failed_count >= total_photos && total_photos.positive?
  end

  def start!
    update!(status: "in_progress", started_at: Time.current)
  end

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def fail!(message)
    update!(status: "failed", error_message: message, completed_at: Time.current)
  end

  def increment_imported!
    increment!(:imported_count)
  end

  def increment_failed!
    increment!(:failed_count)
  end
end
