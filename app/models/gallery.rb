class Gallery < ApplicationRecord
  belongs_to :user
  has_many :uploads, dependent: :destroy

  validates :title, presence: true
  validates :user, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
