class BalanceEvent < ActiveRecord::Base
  belongs_to :account
  belongs_to :bill
  belongs_to :account_entry
  has_many   :bill_share_balance_entries, primary_key: :bill_id, foreign_key: :bill_id
  has_one    :bill_offset_balance_entry, primary_key: :bill_id, foreign_key: :bill_id
  has_one    :pot_balance_entry, primary_key: :bill_id, foreign_key: :bill_id
  has_one    :account_offset_balance_entry, primary_key: :account_entry_id, foreign_key: :account_entry_id

  scope :default_order,             -> { order 'balance_events.date DESC, balance_events.account_entry_id DESC, balance_events.bill_id DESC' }
  scope :all_includes,              -> { includes({:bill => [:bill_share_balance_entries, :bill_offset_balance_entry, :shareholder, :bill_type], :account_entry => :shareholder}) }
  scope :deposits,                  -> { where 'balance_events.account_entry_id IN (SELECT id FROM account_entries WHERE amount >= 0)' }
  scope :withdrawals,               -> { where 'balance_events.account_entry_id IN (SELECT id FROM account_entries WHERE amount < 0)' }
  scope :with_bill_type_id,         -> (bill_type_id) { where('balance_events.bill_id IN (SELECT id FROM bills WHERE bill_type_id = ?)',bill_type_id) }
  scope :starting_on,               -> (start_date) { where("balance_events.date >= ?", start_date) }
  scope :ending_on,                 -> (end_date) { where("balance_events.date <= ?", end_date) }
  scope :with_payee_shareholder_id, -> (shareholder) {
                                            where "(balance_events.bill_id IN (
                                                    SELECT id
                                                    FROM bills
                                                    WHERE shareholder_id = ?) OR
                                                    balance_events.account_entry_id IN (
                                                      SELECT id
                                                      FROM account_entries
                                                      WHERE shareholder_id = ?
                                                    ))", shareholder, shareholder }
  scope :with_share_shareholder_id, -> (shareholder) {
                                            where('(balance_events.bill_id IN (
                                                    SELECT bill_id
                                                    FROM balance_entries
                                                    WHERE shareholder_id = ?) OR
                                                    balance_events.account_entry_id IN (
                                                      SELECT account_entry_id
                                                      FROM balance_entries
                                                      WHERE shareholder_id = ?
                                                    ))',shareholder, shareholder) }
  scope :with_text,                 -> (shareholder) {
                                            where("balance_events.bill_id IN (
                                                  SELECT id
                                                  FROM bills
                                                  WHERE payee ILIKE :text OR note ILIKE :text) OR
                                                    balance_events.account_entry_id IN (
                                                      SELECT id
                                                      FROM account_entries
                                                      WHERE payee ILIKE :text OR note ILIKE :text
                                                    )", text: "%#{text}%") }
  
  def self.unique_shareholders
    ids = joins("INNER JOIN balance_entries ON balance_events.bill_id = balance_entries.bill_id OR balance_events.account_entry_id = balance_entries.account_entry_id").where("shareholder_id IS NOT NULL").reorder(:shareholder_id).uniq.pluck(:shareholder_id).map{|id| id.to_i}
    Shareholder.where(:id => ids).order(:name)
  end
end
