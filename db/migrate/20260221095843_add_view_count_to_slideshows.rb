class AddViewCountToSlideshows < ActiveRecord::Migration[8.1]
  def change
    add_column :slideshows, :view_count, :integer, default: 0, null: false
  end
end
