class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.string     :name
      t.references :owner
      t.integer    :lock_version, :default => 0

      t.timestamps
    end
  end

  def self.down
    drop_table :accounts
  end
end
