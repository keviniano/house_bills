class AddIndexesToBalanceModels < ActiveRecord::Migration
  def change
    add_index :balance_events, :bill_id
    add_index :balance_events, :account_entry_id
    add_index :balance_events, :date
    add_index :balance_entries, :bill_id
    add_index :balance_entries, :account_entry_id
  end
end
