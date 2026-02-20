class AddDateTakenToUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :uploads, :date_taken, :date
  end
end
