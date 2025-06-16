class RemoveLastImportAtFromHousesAndResidents < ActiveRecord::Migration[8.0]
  def up
    # Remove from houses table
    remove_column :houses, :last_import_at, :datetime

    # Remove from residents table
    remove_column :residents, :last_import_at, :datetime
  end

  def down
    # Add back to houses table
    add_column :houses, :last_import_at, :datetime

    # Add back to residents table
    add_column :residents, :last_import_at, :datetime
  end
end
