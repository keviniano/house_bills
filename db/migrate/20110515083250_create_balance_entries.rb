class CreateBalanceEntries < ActiveRecord::Migration
  def self.up
    create_table :balance_entries do |t|
      t.string :type, :limit => 25
      t.references :account
      t.references :bill
      t.references :account_entry
      t.references :shareholder
      t.column :share, :integer
      t.column :amount, :decimal, :precision => 10, :scale => 2
      t.boolean :is_pot_entry, :default => false
      t.column :lock_version, :integer, :default => 0

      t.timestamps
    end
  end

  def self.down
    drop_table :balance_entries
  end
end
