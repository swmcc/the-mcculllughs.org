class SlideshowUpload < ApplicationRecord
  belongs_to :slideshow
  belongs_to :upload
end
