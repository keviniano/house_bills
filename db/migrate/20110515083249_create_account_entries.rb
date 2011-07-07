class CreateAccountEntries < ActiveRecord::Migration
  def self.up
    create_table :account_entries do |t|
      t.string :type, :limit => 25
      t.references :bill
      t.references :balance_offset
      t.references :shareholder
      t.references :account
      t.column :check_number, :integer
      t.column :entered_on,   :date, :null => false
      t.column :payee,        :string, :limit => 100
      t.column :amount,       :decimal, :precision => 10, :scale => 2, :null => false
      t.column :note,         :text
      t.column :cleared,      :boolean
      t.column :lock_version, :integer, :default => 0

      t.timestamps
    end
  end

  def self.down
    drop_table :account_entries
  end
end
