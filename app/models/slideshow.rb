class Slideshow < ApplicationRecord
  belongs_to :user
  has_many :slideshow_uploads, -> { order(:position) }, dependent: :destroy
  has_many :uploads, through: :slideshow_uploads

  has_one_attached :audio

  validates :title, presence: true
  validates :interval, numericality: { in: 1..60 }
  validates :short_code, presence: true, uniqueness: true

  before_validation :generate_short_code, on: :create

  private

  def generate_short_code
    return if short_code.present?

    loop do
      self.short_code = SecureRandom.alphanumeric(8).downcase
      break unless Slideshow.exists?(short_code: short_code)
    end
  end
end
