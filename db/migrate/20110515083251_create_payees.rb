class CreatePayees < ActiveRecord::Migration
  def self.up
    create_table :payees do |t|
      t.column :name, :string
      t.references :account
      t.column :lock_version, :integer, :default => 0
      t.timestamps
    end
    add_index :payees, :name, :unique => 0
  end

  def self.down
    drop_table :payees
  end
end
