class AddArchivedAtToLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :links, :archived_at, :datetime
    add_index :links, :archived_at
  end
end
