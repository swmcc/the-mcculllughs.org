# frozen_string_literal: true

class CreateExternalConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :external_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :access_token
      t.string :access_secret
      t.string :refresh_token
      t.datetime :token_expires_at
      t.string :external_user_id
      t.string :external_username
      t.datetime :connected_at

      t.timestamps
    end

    add_index :external_connections, [ :user_id, :provider ], unique: true
  end
end
