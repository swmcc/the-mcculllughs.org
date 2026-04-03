class AddExifDataToUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :uploads, :exif_data, :jsonb
  end
end
