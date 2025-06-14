class RenameLastSeenAtToMovedOutAt < ActiveRecord::Migration[8.0]
  def change
    rename_column :residents, :last_seen_at, :moved_out_at

    # Update the index as well
    if index_exists?(:residents, [ :house_id, :last_seen_at ], name: "index_residents_on_house_id_and_last_seen_at")
      remove_index :residents, name: "index_residents_on_house_id_and_last_seen_at"
    end

    unless index_exists?(:residents, [ :house_id, :moved_out_at ], name: "index_residents_on_house_id_and_moved_out_at")
      add_index :residents, [ :house_id, :moved_out_at ], name: "index_residents_on_house_id_and_moved_out_at"
    end
  end
end
