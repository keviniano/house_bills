class BalanceEntry < ActiveRecord::Base
  stampable
  belongs_to :bill
  belongs_to :shareholder
  belongs_to :account
  belongs_to :account_entry

  validates_presence_of :account_id
  validates_presence_of :amount
  validates_presence_of :date
  
  scope :unique_shareholders, select(:shareholder_id).where("shareholder_id IS NOT NULL").uniq.includes(:shareholder)
  scope :by_shareholder, lambda{|shareholder| where(:shareholder_id => shareholder.id)}
  scope :starting_on, lambda{|start_date| where("balance_entries.date >= ?", start_date)}
  scope :ending_on, lambda{|end_date| where("balance_entries.date <= ?", end_date)}

  default_value_for :date do
    Date.today
  end
end
