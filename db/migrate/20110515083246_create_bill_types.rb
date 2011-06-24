class CreateBillTypes < ActiveRecord::Migration
  def self.up
    create_table :bill_types do |t|
      t.references :account
      t.text :name
      t.integer :lock_version, :default => 0

      t.timestamps
    end
    add_index :bill_types, :name, :unique => true
  end

  def self.down
    drop_table :bill_types
  end
end
