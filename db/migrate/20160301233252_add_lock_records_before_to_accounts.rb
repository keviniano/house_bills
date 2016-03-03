class AddLockRecordsBeforeToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :lock_records_before, :date
  end
end
