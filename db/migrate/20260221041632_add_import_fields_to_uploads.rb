# frozen_string_literal: true

class AddImportFieldsToUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :uploads, :external_photo_id, :string
    add_column :uploads, :import_id, :bigint
    add_column :uploads, :import_metadata, :jsonb, default: {}

    add_index :uploads, [ :external_photo_id, :import_id ]
    add_index :uploads, :import_metadata, using: :gin
    add_foreign_key :uploads, :imports
  end
end
