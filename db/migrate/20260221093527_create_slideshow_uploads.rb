class CreateSlideshowUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :slideshow_uploads do |t|
      t.references :slideshow, null: false, foreign_key: true
      t.references :upload, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end
    add_index :slideshow_uploads, [ :slideshow_id, :position ]
  end
end
