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

  scope :events, select('balance_entries.bill_id,balance_entries.account_entry_id,balance_entries.date').
    group('balance_entries.bill_id,balance_entries.account_entry_id,balance_entries.date').
    includes({:bill => [:shareholder, :bill_type, :bill_share_balance_entries, :bill_offset_balance_entry],:account_entry => :shareholder})

  scope :by_shareholder, lambda{|shareholder| where(:shareholder_id => shareholder.id)}
  scope :starting_on, lambda{|start_date| where("date >= ?", start_date)}
  scope :ending_on, lambda{|end_date| where("date <= ?", end_date)}
  scope :with_payee_shareholder_id, lambda{|shareholder| where("bill_id IN (SELECT id FROM bills WHERE shareholder_id = ?) OR account_entry_id IN (SELECT id FROM account_entries WHERE shareholder_id = ?)", shareholder, shareholder)}
  scope :with_share_shareholder_id, lambda{|shareholder| where(:shareholder_id => shareholder)}
  scope :with_text, lambda{|text| where("bill_id IN (SELECT id FROM bills WHERE payee ILIKE :text OR note ILIKE :text) OR account_entry_id IN (SELECT id FROM account_entries WHERE payee ILIKE :text OR note ILIKE :text)", text: "%#{text}%")}
  scope :deposits, where('account_entry_id IN (SELECT id FROM account_entries WHERE amount >= 0)')
  scope :withdrawals, where('account_entry_id IN (SELECT id FROM account_entries WHERE amount < 0)')
  scope :with_bill_type_id, lambda{|bill_type_id| where('bill_id IN (SELECT id FROM bills WHERE bill_type_id = ?)',bill_type_id)}

  default_value_for :date do
    Date.today
  end
end
