class AddEmbeddingToUploads < ActiveRecord::Migration[8.1]
  def change
    # Enable pgvector extension if not already enabled
    enable_extension "vector" unless extension_enabled?("vector")

    add_column :uploads, :embedding, :vector, limit: 768
  end
end
