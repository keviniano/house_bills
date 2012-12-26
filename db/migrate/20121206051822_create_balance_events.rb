class CreateBalanceEvents < ActiveRecord::Migration
  def change
    create_table :balance_events do |t|
      t.date :date
      t.references :account
      t.references :bill
      t.references :account_entry
    end
  end
end
