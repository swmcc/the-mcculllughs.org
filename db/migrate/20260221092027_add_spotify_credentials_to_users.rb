class AddSpotifyCredentialsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :spotify_client_id, :string
    add_column :users, :spotify_client_secret, :string
  end
end
