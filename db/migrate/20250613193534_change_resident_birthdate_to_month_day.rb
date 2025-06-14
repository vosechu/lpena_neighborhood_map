class ChangeResidentBirthdateToMonthDay < ActiveRecord::Migration[8.0]
  def up
    # First, convert existing birthdate data to month-day format
    Resident.where.not(birthdate: nil).find_each do |resident|
      # Convert existing date to MM-DD format
      month_day = resident.birthdate.strftime("%m-%d")
      resident.update_column(:birthdate, month_day)
    end

    # Change the column type from date to string
    change_column :residents, :birthdate, :string
  end

  def down
    # This is a lossy migration - we can't restore the original years
    # So we'll just change the column type back to date and set existing values to nil
    change_column :residents, :birthdate, :date

    # Clear all birthdate values since we can't restore the years
    Resident.update_all(birthdate: nil)
  end
end
