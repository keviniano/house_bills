class ChangeBillTypeName < ActiveRecord::Migration
  def self.up
    change_column :bill_types, :name, :string
  end

  def self.down
    change_column :bill_types, :name, :text
  end
end
