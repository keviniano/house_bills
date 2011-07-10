class ChangeEnteredOnToDateInAccountEntries < ActiveRecord::Migration
  def self.up
    change_table :account_entries do |t|
      t.rename :entered_on, :date
    end
  end

  def self.down
    change_table :account_entries do |t|
      t.rename :date, :entered_on
    end
  end
end
