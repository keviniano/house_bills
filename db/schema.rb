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

ActiveRecord::Schema[8.1].define(version: 2026_10_23_120000) do
  create_table "account_entries", force: :cascade do |t|
    t.string "type"
    t.integer "bill_id"
    t.integer "shareholder_id"
    t.integer "account_id"
    t.integer "check_number"
    t.date "date", null: false
    t.string "payee"
    t.integer "amount_cents", default: 0, null: false
    t.text "note"
    t.boolean "cleared"
    t.integer "lock_version", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.integer "updater_id"
    t.index ["account_id"], name: "index_account_entries_on_account_id"
    t.index ["bill_id"], name: "index_account_entries_on_bill_id"
    t.index ["creator_id"], name: "index_account_entries_on_creator_id"
    t.index ["shareholder_id"], name: "index_account_entries_on_shareholder_id"
    t.index ["updater_id"], name: "index_account_entries_on_updater_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name"
    t.integer "owner_id"
    t.date "lock_records_before"
    t.integer "lock_version", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.integer "updater_id"
    t.index ["creator_id"], name: "index_accounts_on_creator_id"
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
    t.index ["updater_id"], name: "index_accounts_on_updater_id"
  end

  create_table "balance_entries", force: :cascade do |t|
    t.string "type"
    t.integer "account_id"
    t.integer "bill_id"
    t.integer "account_entry_id"
    t.integer "shareholder_id"
    t.integer "share"
    t.integer "amount_cents", default: 0, null: false
    t.date "date"
    t.integer "lock_version", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.integer "updater_id"
    t.index ["account_entry_id"], name: "index_balance_entries_on_account_entry_id"
    t.index ["account_id"], name: "index_balance_entries_on_account_id"
    t.index ["bill_id"], name: "index_balance_entries_on_bill_id"
    t.index ["creator_id"], name: "index_balance_entries_on_creator_id"
    t.index ["shareholder_id"], name: "index_balance_entries_on_shareholder_id"
    t.index ["updater_id"], name: "index_balance_entries_on_updater_id"
  end

  create_table "balance_events", force: :cascade do |t|
    t.date "date"
    t.integer "account_id"
    t.integer "bill_id"
    t.integer "account_entry_id"
    t.index ["account_entry_id"], name: "index_balance_events_on_account_entry_id"
    t.index ["account_id"], name: "index_balance_events_on_account_id"
    t.index ["bill_id"], name: "index_balance_events_on_bill_id"
    t.index ["date"], name: "index_balance_events_on_date"
  end

  create_table "bill_types", force: :cascade do |t|
    t.integer "account_id"
    t.string "name"
    t.integer "lock_version", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.integer "updater_id"
    t.index ["account_id"], name: "index_bill_types_on_account_id"
    t.index ["creator_id"], name: "index_bill_types_on_creator_id"
    t.index ["updater_id"], name: "index_bill_types_on_updater_id"
  end

  create_table "bills", force: :cascade do |t|
    t.string "type"
    t.integer "bill_type_id", null: false
    t.integer "shareholder_id"
    t.integer "account_id"
    t.string "payee"
    t.date "date", null: false
    t.integer "amount_cents", default: 0, null: false
    t.text "note"
    t.integer "lock_version", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.integer "updater_id"
    t.index ["account_id"], name: "index_bills_on_account_id"
    t.index ["bill_type_id"], name: "index_bills_on_bill_type_id"
    t.index ["creator_id"], name: "index_bills_on_creator_id"
    t.index ["shareholder_id"], name: "index_bills_on_shareholder_id"
    t.index ["updater_id"], name: "index_bills_on_updater_id"
  end

  create_table "payees", force: :cascade do |t|
    t.integer "account_id"
    t.string "name"
    t.integer "lock_version", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.integer "updater_id"
    t.index ["account_id", "name"], name: "index_payees_on_account_id_and_name", unique: true
    t.index ["creator_id"], name: "index_payees_on_creator_id"
    t.index ["updater_id"], name: "index_payees_on_updater_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "shareholders", force: :cascade do |t|
    t.integer "account_id"
    t.integer "user_id"
    t.integer "role_id"
    t.string "name"
    t.string "email"
    t.date "opened_on", null: false
    t.date "inactivated_on"
    t.date "closed_on"
    t.integer "lock_version", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "creator_id"
    t.integer "updater_id"
    t.index ["account_id"], name: "index_shareholders_on_account_id"
    t.index ["creator_id"], name: "index_shareholders_on_creator_id"
    t.index ["role_id"], name: "index_shareholders_on_role_id"
    t.index ["updater_id"], name: "index_shareholders_on_updater_id"
    t.index ["user_id", "account_id"], name: "index_shareholders_on_user_id_and_account_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email", default: "", null: false
    t.string "remember_token"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "account_entries", "accounts"
  add_foreign_key "account_entries", "bills"
  add_foreign_key "account_entries", "shareholders"
  add_foreign_key "account_entries", "users", column: "creator_id"
  add_foreign_key "account_entries", "users", column: "updater_id"
  add_foreign_key "accounts", "users", column: "creator_id"
  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "accounts", "users", column: "updater_id"
  add_foreign_key "balance_entries", "account_entries"
  add_foreign_key "balance_entries", "accounts"
  add_foreign_key "balance_entries", "bills"
  add_foreign_key "balance_entries", "shareholders"
  add_foreign_key "balance_entries", "users", column: "creator_id"
  add_foreign_key "balance_entries", "users", column: "updater_id"
  add_foreign_key "balance_events", "account_entries"
  add_foreign_key "balance_events", "accounts"
  add_foreign_key "balance_events", "bills"
  add_foreign_key "bill_types", "accounts"
  add_foreign_key "bill_types", "users", column: "creator_id"
  add_foreign_key "bill_types", "users", column: "updater_id"
  add_foreign_key "bills", "accounts"
  add_foreign_key "bills", "bill_types"
  add_foreign_key "bills", "shareholders"
  add_foreign_key "bills", "users", column: "creator_id"
  add_foreign_key "bills", "users", column: "updater_id"
  add_foreign_key "payees", "accounts"
  add_foreign_key "payees", "users", column: "creator_id"
  add_foreign_key "payees", "users", column: "updater_id"
  add_foreign_key "shareholders", "accounts"
  add_foreign_key "shareholders", "roles"
  add_foreign_key "shareholders", "users"
  add_foreign_key "shareholders", "users", column: "creator_id"
  add_foreign_key "shareholders", "users", column: "updater_id"
end
