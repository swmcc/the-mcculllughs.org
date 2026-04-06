class AddAnalysisDataToUploads < ActiveRecord::Migration[8.1]
  def change
    add_column :uploads, :analysis_data, :jsonb
  end
end
