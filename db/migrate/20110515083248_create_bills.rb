class CreateBills < ActiveRecord::Migration
  def self.up
    create_table :bills do |t|
      t.string :type, :limit => 25
      t.references :bill_type, :null => false
      t.references :shareholder
      t.references :account
      t.column :payee, :string, :limit => 100
      t.column :entered_on, :date, :null => false
      t.column :amount, :decimal, :precision => 10, :scale => 2, :null => false
      t.column :note, :text
      t.column :lock_version, :integer, :default => 0

      t.timestamps
    end
  end

  def self.down
    drop_table :bills
  end
end
