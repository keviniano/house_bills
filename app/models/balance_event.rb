class BalanceEvent < ApplicationRecord
  belongs_to :account
  belongs_to :bill, optional: true
  belongs_to :account_entry, optional: true
  has_many   :bill_share_balance_entries, primary_key: :bill_id, foreign_key: :bill_id
  has_one    :bill_offset_balance_entry, primary_key: :bill_id, foreign_key: :bill_id
  has_one    :pot_balance_entry, primary_key: :bill_id, foreign_key: :bill_id
  has_one    :account_offset_balance_entry, primary_key: :account_entry_id, foreign_key: :account_entry_id

  scope :default_order,             -> { order 'balance_events.date DESC, balance_events.account_entry_id DESC, balance_events.bill_id DESC' }
  scope :all_includes,              -> { includes({:bill => [:bill_share_balance_entries, :bill_offset_balance_entry, :shareholder, :bill_type], :account_entry => :shareholder}) }
  scope :deposits,                  -> { where 'balance_events.account_entry_id IN (SELECT id FROM account_entries WHERE amount >= 0)' }
  scope :withdrawals,               -> { where 'balance_events.account_entry_id IN (SELECT id FROM account_entries WHERE amount < 0)' }
  scope :with_bill_type_id,         -> (bill_type_id)   { where('balance_events.bill_id IN (SELECT id FROM bills WHERE bill_type_id = ?)',bill_type_id) }
  scope :starting_on,               -> (start_date)     { where("balance_events.date >= ?", start_date) }
  scope :ending_on,                 -> (end_date)       { where("balance_events.date <= ?", end_date) }
  scope :created_at_start_date,     -> (start_date)     { where("COALESCE(x_bills.created_at, x_account_entries.created_at) >= ?", start_date) }
  scope :created_at_end_date,       -> (end_date)       { where("COALESCE(x_bills.created_at, x_account_entries.created_at) <  ?", end_date + 1.day) }
  scope :updated_at_start_date,     -> (start_date)     { where("COALESCE(x_bills.updated_at, x_account_entries.updated_at) >= ?", start_date) }
  scope :updated_at_end_date,       -> (end_date)       { where("COALESCE(x_bills.updated_at, x_account_entries.updated_at) <  ?", end_date + 1.day) }
  scope :changed_at_start_date,     -> (start_date)     { where("COALESCE(x_bills.created_at, x_account_entries.created_at) >= :start_date OR " +
                                                                "COALESCE(x_bills.updated_at, x_account_entries.updated_at) >= :start_date", start_date: start_date) }
  scope :changed_at_end_date,       -> (end_date)       { where("COALESCE(x_bills.created_at, x_account_entries.created_at) <  :end_date OR " +
                                                                "COALESCE(x_bills.updated_at, x_account_entries.updated_at) <  :end_date", end_date: end_date + 1.day) }
  scope :join_bills_and_account_entries, -> { joins("LEFT OUTER JOIN bills AS x_bills ON balance_events.bill_id = x_bills.id").
                                              joins("LEFT OUTER JOIN account_entries AS x_account_entries ON balance_events.account_entry_id = x_account_entries.id") }
  scope :with_payee_shareholder_id, -> (shareholder_id) {
                                            where "(balance_events.bill_id IN (
                                                      SELECT id
                                                      FROM bills
                                                      WHERE shareholder_id = :shareholder_id) OR
                                                    balance_events.account_entry_id IN (
                                                      SELECT id
                                                      FROM account_entries
                                                      WHERE shareholder_id = :shareholder_id)
                                                    )", shareholder_id: shareholder_id }
  scope :with_share_shareholder_id, -> (shareholder_id) {
                                            where("balance_events.bill_id IN (
                                                     SELECT bill_id
                                                     FROM balance_entries
                                                     WHERE type = 'BillShareBalanceEntry' AND shareholder_id = ?)", shareholder_id) }
  scope :with_text,                 -> (text) {
                                            where("(balance_events.bill_id IN (
                                                     SELECT id
                                                     FROM bills
                                                     WHERE payee ILIKE :text OR note ILIKE :text) OR
                                                   balance_events.account_entry_id IN (
                                                     SELECT id
                                                     FROM account_entries
                                                     WHERE payee ILIKE :text OR note ILIKE :text)
                                                   )", text: "%#{text}%") }

  def self.sum_of_amounts
    joins(:bill).
      sum("bills.amount") +
    joins(:account_entry).
      sum("account_entries.amount")
  end

  def self.sum_of_share_amounts(shareholder_id)
    joins(:bill_share_balance_entries).
      where(balance_entries: {shareholder_id: shareholder_id}).
      sum("balance_entries.amount")
  end

  def self.sum_of_offset_amounts(shareholder_id)
    joins(:bill_offset_balance_entry).
      where(balance_entries: {shareholder_id: shareholder_id}).
      sum("balance_entries.amount") +
    joins(:account_offset_balance_entry).
      where(balance_entries: {shareholder_id: shareholder_id}).
      sum("balance_entries.amount")
  end
end
