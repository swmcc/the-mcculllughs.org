# frozen_string_literal: true

class ExternalConnection < ApplicationRecord
  PROVIDERS = %w[flickr google facebook].freeze

  belongs_to :user
  has_many :imports, dependent: :nullify

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider, uniqueness: { scope: :user_id, message: "already connected" }

  encrypts :access_token
  encrypts :access_secret
  encrypts :refresh_token
  encrypts :api_key
  encrypts :api_secret

  def has_api_credentials?
    api_key.present? && api_secret.present?
  end

  scope :for_provider, ->(provider) { where(provider: provider) }

  def connected?
    access_token.present?
  end

  def token_expired?
    return false unless token_expires_at
    token_expires_at < Time.current
  end

  def disconnect!
    destroy
  end
end
