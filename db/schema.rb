# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120308061021) do

  create_table "account_entries", :force => true do |t|
    t.string   "type",              :limit => 25
    t.integer  "bill_id"
    t.integer  "balance_offset_id"
    t.integer  "shareholder_id"
    t.integer  "account_id"
    t.integer  "check_number"
    t.date     "date",                                                                           :null => false
    t.string   "payee",             :limit => 100
    t.decimal  "amount",                           :precision => 10, :scale => 2,                :null => false
    t.text     "note"
    t.boolean  "cleared"
    t.integer  "lock_version",                                                    :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  create_table "accounts", :force => true do |t|
    t.string   "name"
    t.integer  "owner_id"
    t.integer  "lock_version", :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  create_table "balance_entries", :force => true do |t|
    t.string   "type",             :limit => 25
    t.integer  "account_id"
    t.integer  "bill_id"
    t.integer  "account_entry_id"
    t.integer  "shareholder_id"
    t.integer  "share"
    t.decimal  "amount",                         :precision => 10, :scale => 2
    t.boolean  "is_pot_entry",                                                  :default => false
    t.integer  "lock_version",                                                  :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "date"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  create_table "bill_types", :force => true do |t|
    t.integer  "account_id"
    t.string   "name"
    t.integer  "lock_version", :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  create_table "bills", :force => true do |t|
    t.string   "type",           :limit => 25
    t.integer  "bill_type_id",                                                                :null => false
    t.integer  "shareholder_id"
    t.integer  "account_id"
    t.string   "payee",          :limit => 100
    t.date     "date",                                                                        :null => false
    t.decimal  "amount",                        :precision => 10, :scale => 2,                :null => false
    t.text     "note"
    t.integer  "lock_version",                                                 :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  create_table "payees", :force => true do |t|
    t.string   "name"
    t.integer  "account_id"
    t.integer  "lock_version", :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  add_index "payees", ["name"], :name => "index_payees_on_name", :unique => true

  create_table "roles", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "shareholders", :force => true do |t|
    t.integer  "account_id"
    t.integer  "user_id"
    t.integer  "role_id"
    t.string   "name",           :limit => 50
    t.string   "email"
    t.date     "opened_on",                                   :null => false
    t.date     "inactivated_on"
    t.date     "closed_on"
    t.integer  "lock_version",                 :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "creator_id"
    t.integer  "updater_id"
  end

  add_index "shareholders", ["user_id", "account_id"], :name => "index_shareholders_on_user_id_and_account_id", :unique => true

  create_table "users", :force => true do |t|
    t.string   "name"
    t.string   "email",                                 :default => "", :null => false
    t.string   "encrypted_password",     :limit => 128, :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                         :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "password_salt"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.integer  "failed_attempts",                       :default => 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.string   "authentication_token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["authentication_token"], :name => "index_users_on_authentication_token", :unique => true
  add_index "users", ["confirmation_token"], :name => "index_users_on_confirmation_token", :unique => true
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true
  add_index "users", ["unlock_token"], :name => "index_users_on_unlock_token", :unique => true

end
