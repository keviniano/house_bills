# Recreates the 2016 Postgres schema for SQLite in one step, with money stored as
# integer cents, foreign keys on every reference, and Google sign-in columns on users.
class CreateHouseBills < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name
      t.timestamps null: true
    end

    create_table :users do |t|
      t.string   :provider
      t.string   :uid
      t.string   :name
      t.string   :email, null: false, default: ""
      t.datetime :remember_created_at
      t.integer  :sign_in_count, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.timestamps null: true
    end
    add_index :users, :email, unique: true
    add_index :users, [ :provider, :uid ], unique: true

    create_table :accounts do |t|
      t.string     :name
      t.references :owner, foreign_key: { to_table: :users }
      t.date       :lock_records_before
      t.integer    :lock_version, default: 0
      t.timestamps null: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :updater, foreign_key: { to_table: :users }
    end

    create_table :shareholders do |t|
      t.references :account, foreign_key: true
      t.references :user, foreign_key: true, index: false
      t.references :role, foreign_key: true
      t.string     :name
      t.string     :email
      t.date       :opened_on, null: false
      t.date       :inactivated_on
      t.date       :closed_on
      t.integer    :lock_version, default: 0
      t.timestamps null: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :updater, foreign_key: { to_table: :users }
    end
    add_index :shareholders, [ :user_id, :account_id ], unique: true

    create_table :bill_types do |t|
      t.references :account, foreign_key: true
      t.string     :name
      t.integer    :lock_version, default: 0
      t.timestamps null: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :updater, foreign_key: { to_table: :users }
    end

    create_table :payees do |t|
      t.references :account, foreign_key: true, index: false
      t.string     :name
      t.integer    :lock_version, default: 0
      t.timestamps null: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :updater, foreign_key: { to_table: :users }
    end
    add_index :payees, [ :account_id, :name ], unique: true

    create_table :bills do |t|
      t.string     :type
      t.references :bill_type, null: false, foreign_key: true
      t.references :shareholder, foreign_key: true
      t.references :account, foreign_key: true
      t.string     :payee
      t.date       :date, null: false
      t.integer    :amount_cents, null: false, default: 0
      t.text       :note
      t.integer    :lock_version, default: 0
      t.timestamps null: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :updater, foreign_key: { to_table: :users }
    end

    create_table :account_entries do |t|
      t.string     :type
      t.references :bill, foreign_key: true
      # Unused by the 2017 code; kept so the legacy import loses nothing.
      t.integer    :balance_offset_id
      t.references :shareholder, foreign_key: true
      t.references :account, foreign_key: true
      t.integer    :check_number
      t.date       :date, null: false
      t.string     :payee
      t.integer    :amount_cents, null: false, default: 0
      t.text       :note
      t.boolean    :cleared
      t.integer    :lock_version, default: 0
      t.timestamps null: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :updater, foreign_key: { to_table: :users }
    end

    create_table :balance_entries do |t|
      t.string     :type
      t.references :account, foreign_key: true
      t.references :bill, foreign_key: true
      t.references :account_entry, foreign_key: true
      t.references :shareholder, foreign_key: true
      t.integer    :share
      t.integer    :amount_cents, null: false, default: 0
      # Unused by the 2017 code (PotBalanceEntry is the STI type); kept for the legacy import.
      t.boolean    :is_pot_entry, default: false
      t.date       :date
      t.integer    :lock_version, default: 0
      t.timestamps null: true
      t.references :creator, foreign_key: { to_table: :users }
      t.references :updater, foreign_key: { to_table: :users }
    end

    create_table :balance_events do |t|
      t.date       :date, index: true
      t.references :account, foreign_key: true
      t.references :bill, foreign_key: true
      t.references :account_entry, foreign_key: true
    end

    create_table :versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id, null: false
      t.string   :event, null: false
      t.string   :whodunnit
      t.text     :object
      t.datetime :created_at
    end
    add_index :versions, [ :item_type, :item_id ]
  end
end
