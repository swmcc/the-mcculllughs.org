# frozen_string_literal: true

class ApiKey < ApplicationRecord
  SCOPES = %w[admin photos:create].freeze

  belongs_to :user

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :scope, inclusion: { in: SCOPES }

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  before_validation :generate_key, on: :create

  # Scope check - an admin key can do everything, other keys only their own scope
  def can?(required_scope)
    scope == "admin" || scope == required_scope
  end

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  private

  def generate_key
    self.key = "sk_#{SecureRandom.hex(32)}"
  end
end
