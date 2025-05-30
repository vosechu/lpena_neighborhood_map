# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_05_09_210228) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "houses", force: :cascade do |t|
    t.string "pcpa_uid", null: false
    t.integer "street_number", null: false
    t.string "street_name", null: false
    t.string "city", null: false
    t.string "state", null: false
    t.string "zip"
    t.decimal "latitude", precision: 10, scale: 8
    t.decimal "longitude", precision: 11, scale: 8
    t.json "boundary_geometry"
    t.datetime "last_import_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pcpa_uid"], name: "index_houses_on_pcpa_uid", unique: true
    t.index ["street_number", "street_name"], name: "index_houses_on_street_number_and_street_name"
  end

  create_table "residents", force: :cascade do |t|
    t.bigint "house_id", null: false
    t.string "official_name", null: false
    t.string "secondary_official_name"
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at"
    t.datetime "last_import_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name"
    t.string "phone"
    t.string "email"
    t.date "birthdate"
    t.date "welcomed_on"
    t.boolean "share_email", default: false, null: false
    t.boolean "share_phone", default: false, null: false
    t.boolean "share_birthdate", default: false, null: false
    t.boolean "share_display_name", default: false, null: false
    t.boolean "public_visibility", default: false, null: false
    t.bigint "user_id"
    t.string "homepage"
    t.text "skills"
    t.text "comments"
    t.boolean "hidden"
    t.index ["email"], name: "index_residents_on_email"
    t.index ["house_id", "last_seen_at"], name: "index_residents_on_house_id_and_last_seen_at"
    t.index ["house_id"], name: "index_residents_on_house_id"
    t.index ["official_name"], name: "index_residents_on_official_name"
    t.index ["user_id"], name: "index_residents_on_user_id"
    t.index ["welcomed_on"], name: "index_residents_on_welcomed_on"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "residents", "houses"
  add_foreign_key "residents", "users"
end
