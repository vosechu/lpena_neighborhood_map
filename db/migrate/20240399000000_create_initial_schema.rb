class CreateInitialSchema < ActiveRecord::Migration[8.0]
  def change
    # Create houses table
    create_table :houses do |t|
      t.string :pcpa_uid, null: false
      t.integer :street_number, null: false
      t.string :street_name, null: false
      t.string :city, null: false
      t.string :state, null: false
      t.string :zip
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8
      t.json :boundary_geometry
      t.datetime :last_import_at

      t.timestamps
    end

    add_index :houses, :pcpa_uid, unique: true
    add_index :houses, [:street_number, :street_name]

    # Create users table
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true

    # Create residents table
    create_table :residents do |t|
      t.references :house, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :official_name, null: false
      t.string :secondary_official_name
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at
      t.datetime :last_import_at
      t.string :display_name
      t.string :phone
      t.string :email
      t.date :birthdate
      t.date :welcomed_on
      t.boolean :share_email, default: false, null: false
      t.boolean :share_phone, default: false, null: false
      t.boolean :share_birthdate, default: false, null: false
      t.boolean :share_display_name, default: false, null: false
      t.boolean :public_visibility, default: false, null: false

      t.timestamps
    end

    add_index :residents, [:house_id, :official_name]
    add_index :residents, :user_id
  end
end
