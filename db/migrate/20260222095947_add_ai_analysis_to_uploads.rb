class AddAiAnalysisToUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :uploads, :analysis_status, :string, default: "pending", null: false
    add_column :uploads, :analysis_error, :text
    add_column :uploads, :analyzed_at, :datetime
    add_column :uploads, :analysis_version, :string
    add_column :uploads, :ai_analysis, :jsonb, default: {}
    add_column :uploads, :embedding, :vector, limit: 768

    add_index :uploads, :analysis_status
    add_index :uploads, :ai_analysis, using: :gin
    add_index :uploads, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
