class BalanceEntry < ActiveRecord::Base
  belongs_to :bill
  belongs_to :shareholder
  belongs_to :account
  belongs_to :account_entry

  validates_presence_of :account_id
  validates_presence_of :amount
  validates_presence_of :date
  
  default_value_for :date do
    Date.today
  end
end
