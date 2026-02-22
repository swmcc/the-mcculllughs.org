class Upload < ApplicationRecord
  include Neighbor::Model

  belongs_to :user
  belongs_to :gallery
  belongs_to :import, optional: true

  # Active Storage attachments
  has_one_attached :file
  has_one_attached :thumbnail

  # Callbacks
  before_validation :generate_short_code, on: :create
  after_commit :process_media, on: :create

  # Vector embedding for similarity search
  has_neighbors :embedding

  # Validations
  validates :file, presence: true
  validates :user, presence: true
  validates :gallery, presence: true
  validates :short_code, presence: true, uniqueness: true
  validates :analysis_status, inclusion: { in: %w[pending processing completed failed] }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :images, -> { where("uploads.file_content_type LIKE ?", "image/%") }
  scope :videos, -> { where("uploads.file_content_type LIKE ?", "video/%") }
  scope :publicly_visible, -> { where(is_public: true) }
  scope :from_import, -> { where.not(import_id: nil) }

  # AI analysis scopes
  scope :analysis_pending, -> { where(analysis_status: "pending") }
  scope :analysis_processing, -> { where(analysis_status: "processing") }
  scope :analysis_completed, -> { where(analysis_status: "completed") }
  scope :analysis_failed, -> { where(analysis_status: "failed") }
  scope :needs_analysis, -> { analysis_pending.images }
  scope :with_embedding, -> { where.not(embedding: nil) }

  # Import helpers
  def imported?
    external_photo_id.present?
  end

  # AI analysis helpers
  def analyzed?
    analysis_status == "completed"
  end

  def mark_analysis_started!
    update!(analysis_status: "processing")
  end

  def complete_analysis!(analysis_data, embedding_vector, version)
    update!(
      analysis_status: "completed",
      ai_analysis: analysis_data,
      embedding: embedding_vector,
      analysis_version: version,
      analyzed_at: Time.current,
      analysis_error: nil
    )
  end

  def fail_analysis!(error_message)
    update!(
      analysis_status: "failed",
      analysis_error: error_message
    )
  end

  def find_similar(limit: 10)
    return Upload.none unless embedding.present?

    Upload
      .where.not(id: id)
      .with_embedding
      .nearest_neighbors(:embedding, embedding, distance: :cosine)
      .limit(limit)
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
