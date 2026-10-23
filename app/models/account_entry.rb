class AccountEntry < ApplicationRecord
  include MoneyColumn
  include Userstamps

  before_validation :set_amount

  belongs_to :bill, optional: true
  belongs_to :shareholder, optional: true
  belongs_to :account, optional: true
  has_one    :account_offset_balance_entry, :dependent => :destroy, :autosave => true
  has_one    :balance_event, :dependent => :destroy, :autosave => true

  has_paper_trail

  money_attribute :amount
  attribute :date, default: -> { Date.current }
  attribute :cleared, default: false

  validates_presence_of     :entry_amount
  validates_presence_of     :entry_type
  validates_numericality_of :check_number, :allow_nil => true
  validates_presence_of     :date
  validates_associated      :account_offset_balance_entry

  scope :with_text,    -> (text) { where("payee LIKE :text OR note LIKE :text", text: "%#{text}%")}
  scope :starting_on,  -> (start_date) { where("date >= ?", start_date)}
  scope :ending_on,    -> (end_date) { where("date <= ?", end_date)}
  scope :deposits,     -> { where 'amount_cents >= 0' }
  scope :withdrawals,  -> { where 'amount_cents < 0' }
  scope :cleared,      -> { where cleared: true }
  scope :pending,      -> { where cleared: false }
  scope :with_payee_shareholder_id, -> (shareholder) { where(shareholder_id: shareholder)}

  def open_shareholders
    account.shareholders.open_as_of(date) if account.present?
  end

  def recipient
    shareholder.present? ? shareholder.name : payee
  end

  def self.valid_entry_types
    %w( Deposit Withdrawal )
  end

  def self.find_in_date_range(start_date, end_date)
    self.where(date: start_date..end_date).order(:date, :check_number, :id)
  end

  def self.balance_before(d)
    self.where('date < ?', d).sum_money
  end

  def self.balance_as_of(d)
    self.where('date <= ?', d).sum_money
  end

  def self.cleared_balance_before(d)
    self.where('cleared = ? and date < ?', true, d).sum_money
  end

  def self.cleared_balance_as_of(d)
    self.where('cleared = ? and date <= ?', true, d).sum_money
  end

  def balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).
      where("balance_entries.date < ? OR (balance_entries.date = ? AND balance_entries.account_entry_id <= ?)", date, date, id).
      sum_money
  end

  def prior_balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).
      where("balance_entries.date < ? OR (balance_entries.date = ? AND balance_entries.account_entry_id < ?)", date, date, id).
      sum_money
  end

  # Running balances on the account register, up to and including (or just before) this entry.
  def cleared_balance
    account_entries_in_account.where(cleared: true).where('date < ? or (date = ? and id <= ?)', date, date, id).sum_money
  end

  def prior_cleared_balance
    account_entries_in_account.where(cleared: true).where('date < ? or (date = ? and id < ?)', date, date, id).sum_money
  end

  def this_balance
    account_entries_in_account.where('date < ? or (date = ? and id <= ?)', date, date, id).sum_money
  end

  def prior_balance
    account_entries_in_account.where('date < ? or (date = ? and id < ?)', date, date, id).sum_money
  end

  def entry_type
    @entry_type || ( amount < 0 ? 'Withdrawal' : 'Deposit' )
  end

  def entry_type=(val)
    @entry_type = val
  end

  def deposit_amount
    amount if amount >= 0
  end

  def withdrawal_amount
    -amount if amount < 0
  end

  def entry_amount=(val)
    @entry_amount = val
  end

  def shareholder_offset_amount(sh)
    shareholder_id == sh.id ? amount : 0
  end

  def entry_amount
    ApplicationController.helpers.number_with_precision(@entry_amount || amount.abs, :precision => 2) unless @entry_amount.nil? && amount.nil?
  end

  def locked?
    if account.present?
      if account.lock_records_before.present?
        date < account.lock_records_before
      else
        false
      end
    else
      true
    end
  end

private

  def account_entries_in_account
    AccountEntry.where(account_id: account_id)
  end

  def set_amount
    if @entry_amount.present?
      self.amount = (entry_type == 'Withdrawal' ? - @entry_amount.to_d : @entry_amount)
    end
  end
end
