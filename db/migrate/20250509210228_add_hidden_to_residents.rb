class AddHiddenToResidents < ActiveRecord::Migration[8.0]
  def change
    add_column :residents, :hidden, :boolean
  end
end
