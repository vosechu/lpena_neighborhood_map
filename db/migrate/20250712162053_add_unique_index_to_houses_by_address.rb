class AddUniqueIndexToHousesByAddress < ActiveRecord::Migration[8.0]
  def change
    # Add unique index to prevent duplicate houses with same address
    add_index :houses, [ :street_number, :street_name, :city ], unique: true, name: 'index_houses_on_address_unique'

    # Remove the unique constraint on pcpa_uid since it's not stable
    remove_index :houses, :pcpa_uid
    add_index :houses, :pcpa_uid, name: 'index_houses_on_pcpa_uid'
  end
end
