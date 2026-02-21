class Slideshow < ApplicationRecord
  belongs_to :user
  has_many :slideshow_uploads, -> { order(:position) }, dependent: :destroy
  has_many :uploads, through: :slideshow_uploads

  validates :title, presence: true
  validates :interval, numericality: { in: 1..60 }
end
