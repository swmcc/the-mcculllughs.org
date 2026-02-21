class Gallery < ApplicationRecord
  belongs_to :user
  has_many :uploads, dependent: :destroy
  has_many :imports, dependent: :nullify

  validates :title, presence: true
  validates :user, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
