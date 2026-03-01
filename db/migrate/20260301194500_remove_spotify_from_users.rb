# frozen_string_literal: true

class RemoveSpotifyFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :spotify_client_id, :string
    remove_column :users, :spotify_client_secret, :string
  end
end
