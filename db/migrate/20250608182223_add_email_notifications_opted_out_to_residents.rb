class AddEmailNotificationsOptedOutToResidents < ActiveRecord::Migration[8.0]
  def change
    add_column :residents, :email_notifications_opted_out, :boolean, default: false, null: false
  end
end
