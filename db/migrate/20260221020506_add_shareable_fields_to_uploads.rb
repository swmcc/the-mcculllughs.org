class AddShareableFieldsToUploads < ActiveRecord::Migration[8.1]
  def up
    add_column :uploads, :short_code, :string
    add_column :uploads, :is_public, :boolean, default: false, null: false

    # Generate short_codes for existing uploads
    Upload.reset_column_information
    Upload.find_each do |upload|
      loop do
        code = SecureRandom.alphanumeric(6)
        unless Upload.exists?(short_code: code)
          upload.update_column(:short_code, code)
          break
        end
      end
    end

    # Now add the not-null constraint and unique index
    change_column_null :uploads, :short_code, false
    add_index :uploads, :short_code, unique: true
  end

  def down
    remove_index :uploads, :short_code
    remove_column :uploads, :short_code
    remove_column :uploads, :is_public
  end
end
