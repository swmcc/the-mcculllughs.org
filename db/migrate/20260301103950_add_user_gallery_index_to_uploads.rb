class AddUserGalleryIndexToUploads < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :uploads, [ :user_id, :gallery_id, :created_at ],
              name: "index_uploads_on_user_gallery_created",
              algorithm: :concurrently
  end
end
