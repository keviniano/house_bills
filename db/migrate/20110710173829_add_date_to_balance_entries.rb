class AddDateToBalanceEntries < ActiveRecord::Migration
  def self.up
    add_column :balance_entries, :date, :date 
  end

  def self.down
    remove_column :balance_entries, :date
  end
end
