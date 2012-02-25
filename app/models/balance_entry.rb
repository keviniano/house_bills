class BalanceEntry < ActiveRecord::Base
  stampable
  belongs_to :bill
  belongs_to :shareholder
  belongs_to :account
  belongs_to :account_entry

  validates_presence_of :account_id
  validates_presence_of :amount
  validates_presence_of :date
  
  default_scope order('balance_entries.date DESC,balance_entries.account_entry_id DESC,balance_entries.bill_id DESC')

  scope :events, select('balance_entries.bill_id,balance_entries.account_entry_id,balance_entries.date').group('balance_entries.bill_id,balance_entries.account_entry_id,balance_entries.date').includes({:bill => [:shareholder, :bill_type, :bill_share_balance_entries, :bill_offset_balance_entry],:account_entry => :shareholder})

  scope :by_shareholder, lambda{|shareholder| where(:shareholder_id => shareholder.id)}

  default_value_for :date do
    Date.today
  end
end
