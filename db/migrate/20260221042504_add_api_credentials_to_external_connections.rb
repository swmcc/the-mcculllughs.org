class AddApiCredentialsToExternalConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :external_connections, :api_key, :string
    add_column :external_connections, :api_secret, :string
  end
end
