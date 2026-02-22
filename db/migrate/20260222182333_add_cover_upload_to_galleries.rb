class AddCoverUploadToGalleries < ActiveRecord::Migration[8.1]
  def change
    add_reference :galleries, :cover_upload, null: true, foreign_key: { to_table: :uploads }
  end
end
