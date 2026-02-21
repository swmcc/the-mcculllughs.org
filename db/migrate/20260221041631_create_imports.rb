# frozen_string_literal: true

class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :gallery, foreign_key: true
      t.references :external_connection, foreign_key: true
      t.string :provider, null: false
      t.string :external_album_id, null: false
      t.string :album_title
      t.string :status, default: "pending", null: false
      t.integer :total_photos, default: 0
      t.integer :imported_count, default: 0
      t.integer :failed_count, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :imports, [ :user_id, :provider, :external_album_id ], unique: true, name: "idx_imports_user_provider_album"
    add_index :imports, :status
  end
end
