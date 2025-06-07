class FlipPrivacyFlagsToHideFieldsOnResidents < ActiveRecord::Migration[8.0]
  def up
    add_column :residents, :hide_display_name, :boolean, default: false
    add_column :residents, :hide_email, :boolean, default: false
    add_column :residents, :hide_phone, :boolean, default: false
    add_column :residents, :hide_birthdate, :boolean, default: false

    # Migrate data: if share_* is false, set hide_* to true
    Resident.reset_column_information
    Resident.find_each do |resident|
      resident.update_columns(
        hide_display_name: resident.share_display_name == false,
        hide_email: resident.share_email == false,
        hide_phone: resident.share_phone == false,
        hide_birthdate: resident.share_birthdate == false
      )
    end

    remove_column :residents, :share_display_name
    remove_column :residents, :share_email
    remove_column :residents, :share_phone
    remove_column :residents, :share_birthdate
  end

  def down
    add_column :residents, :share_display_name, :boolean, default: false, null: false
    add_column :residents, :share_email, :boolean, default: false, null: false
    add_column :residents, :share_phone, :boolean, default: false, null: false
    add_column :residents, :share_birthdate, :boolean, default: false, null: false

    Resident.reset_column_information
    Resident.find_each do |resident|
      resident.update_columns(
        share_display_name: !resident.hide_display_name,
        share_email: !resident.hide_email,
        share_phone: !resident.hide_phone,
        share_birthdate: !resident.hide_birthdate
      )
    end

    remove_column :residents, :hide_display_name
    remove_column :residents, :hide_email
    remove_column :residents, :hide_phone
    remove_column :residents, :hide_birthdate
  end
end
