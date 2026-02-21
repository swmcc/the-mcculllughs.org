class AddShortCodeToSlideshows < ActiveRecord::Migration[8.1]
  def change
    add_column :slideshows, :short_code, :string
    add_index :slideshows, :short_code, unique: true
  end
end
