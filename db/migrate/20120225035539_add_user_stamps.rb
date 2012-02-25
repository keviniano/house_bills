class AddUserStamps < ActiveRecord::Migration
  def self.up
    change_table :account_entries  do |t| 
      t.integer :creator_id  
      t.integer :updater_id 
    end
    change_table :accounts         do |t| 
      t.integer :creator_id  
      t.integer :updater_id 
    end
    change_table :balance_entries  do |t| 
      t.integer :creator_id  
      t.integer :updater_id 
    end
    change_table :bill_types       do |t| 
      t.integer :creator_id  
      t.integer :updater_id 
    end
    change_table :bills            do |t| 
      t.integer :creator_id  
      t.integer :updater_id 
    end
    change_table :payees           do |t| 
      t.integer :creator_id  
      t.integer :updater_id 
    end
    change_table :shareholders     do |t| 
      t.integer :creator_id  
      t.integer :updater_id 
    end
  end

  def self.down
  end
end
