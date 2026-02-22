class ApiKey < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :scope, presence: true, inclusion: { in: %w[admin read_only] }

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :admin, -> { where(scope: "admin") }

  before_validation :generate_key, on: :create

  def self.authenticate(bearer_token)
    return nil if bearer_token.blank?

    key = active.find_by(key: bearer_token)
    key&.touch(:last_used_at)
    key
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private

  def generate_key
    self.key ||= "mc_#{SecureRandom.hex(32)}"
  end
end
