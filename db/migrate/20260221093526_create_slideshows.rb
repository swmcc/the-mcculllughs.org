class CreateSlideshows < ActiveRecord::Migration[8.1]
  def change
    create_table :slideshows do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :spotify_url
      t.integer :interval, default: 5

      t.timestamps
    end
  end
end
