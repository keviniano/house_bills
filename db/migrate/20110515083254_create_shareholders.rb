class CreateShareholders < ActiveRecord::Migration
  def self.up
    create_table :shareholders do |t|
      t.references :account
      t.references :user
      t.references :role
      t.column :name,           :string, :limit => 50
      t.column :email,          :string
      t.column :opened_on,      :date,   :null => false
      t.column :inactivated_on, :date
      t.column :closed_on,      :date

      t.integer :lock_version, :default => 0
      t.timestamps
    end
    add_index 'shareholders', [:user_id, :account_id], :unique => true
  end

  def self.down
    drop_table :shareholders
  end
end
