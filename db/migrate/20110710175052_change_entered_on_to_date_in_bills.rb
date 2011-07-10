class ChangeEnteredOnToDateInBills < ActiveRecord::Migration
  def self.up
    change_table :bills do |t|
      t.rename :entered_on, :date
    end
  end

  def self.down
    change_table :bills do |t|
      t.rename :date, :entered_on
    end
  end
end
