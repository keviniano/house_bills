class Bill < ApplicationRecord
  include MoneyColumn
  include Userstamps

  belongs_to  :shareholder, optional: true
  belongs_to  :account, optional: true
  belongs_to  :bill_type
  has_many    :bill_share_balance_entries, dependent: :destroy, autosave: true
  has_one     :bill_offset_balance_entry,  dependent: :destroy, autosave: true
  has_one     :pot_balance_entry,          dependent: :destroy, autosave: true
  has_one     :bill_account_entry,         dependent: :destroy, autosave: true
  has_one     :balance_event,              dependent: :destroy, autosave: true

  has_paper_trail

  money_attribute :amount
  attribute :date, default: -> { Date.current }

  before_validation :set_amount
  after_validation  :update_balance_entries, :update_balance_event

  accepts_nested_attributes_for :bill_share_balance_entries, allow_destroy: true,
      reject_if: proc { |attrs| attrs['shareholder_id'].blank? || attrs['share'].blank? || attrs['share'] == '0' }

  MONTH_SQL = "CAST(strftime('%m', bills.date) AS INTEGER)"
  YEAR_SQL  = "CAST(strftime('%Y', bills.date) AS INTEGER)"

  def self.valid_entry_types
    %w( Bill Credit )
  end

  def self.sum_of_bills_by_type_and_month_for_shareholder(shareholder_id)
    select("bills.bill_type_id, #{MONTH_SQL} AS month, #{YEAR_SQL} AS year, -SUM(balance_entries.amount_cents) AS amount_cents").
    joins(:bill_share_balance_entries).
    where("balance_entries.shareholder_id = ?", shareholder_id).
    group("bills.bill_type_id, #{MONTH_SQL}, #{YEAR_SQL}").
    order(Arel.sql("bills.bill_type_id, #{YEAR_SQL}, #{MONTH_SQL}")).
    includes(:bill_type)
  end

  # Splits a bill of bill_cents across integer share ratios. Returns
  # [base_cents, gcd, remainder_cents]: each share gets -(share / gcd) * base_cents and
  # the pot gets remainder_cents. When the bill doesn't divide evenly, the base portion is
  # one cent above the floor of the exact split (rounded up for bills, towards zero for
  # credits) and the pot takes the difference, exactly as the 2011 Float version did.
  # With no positive shares there's nothing to split, and the remainder is nil.
  def self.calc_shares(share_ratios, bill_cents)
    positive = share_ratios.select(&:positive?)
    return [0, nil, nil] if positive.empty?

    gcd = positive.reduce(:gcd)
    units = share_ratios.sum / gcd

    if bill_cents % units == 0
      [bill_cents / units, gcd, 0]
    else
      base_cents = bill_cents.div(units) + 1
      [base_cents, gcd, units * base_cents - bill_cents]
    end
  end

  def balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).where("balance_entries.date < ? OR (balance_entries.date = ? AND COALESCE(balance_entries.bill_id,?) <= ?)",self.date,self.date,self.id,self.id).sum_money
  end

  def balances_for(shareholders)
    balance_entries = BalanceEntry.for_shareholders(shareholders).where("balance_entries.date < ? OR (balance_entries.date = ? AND COALESCE(balance_entries.bill_id,?) <= ?)",self.date,self.date,self.id,self.id).select('shareholder_id, SUM(amount_cents) AS amount_cents').group('shareholder_id')
    result = {}
    balance_entries.each {|be| result[be.shareholder_id] = be.amount }
    result
  end

  def prior_balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).where("balance_entries.date < ? OR (balance_entries.date = ? AND COALESCE(balance_entries.bill_id,?) < ?)",self.date,self.date,self.id,self.id).sum_money
  end

  validates_presence_of     :entry_type
  validates_inclusion_of    :entry_type, in: valid_entry_types
  validates_numericality_of :entry_amount, greater_than_or_equal_to: 0
  validates_presence_of     :bill_type_id
  validates_presence_of     :date
  validates_associated      :bill_share_balance_entries
  validates_presence_of     :entry_amount
# TODO: Make sure there's always at least one bill share entry

  scope :starting_on, -> (start_date) { where("bills.date >= ?", start_date) }
  scope :ending_on,   -> (end_date) { where("bills.date <= ?", end_date) }

  def open_shareholders
    account.shareholders.open_as_of(date) if account.present?
  end

  def active_shareholders
    account.shareholders.active_as_of(date) if account.present?
  end

  def excluded_open_shareholders
    if account.present?
      open_ids = open_shareholders.map {|s| s.id}
      included_ids = bill_share_balance_entries.map{|b| b.shareholder_id}
      Shareholder.find(open_ids - included_ids)
    else
      []
    end
  end

  def recipient
    shareholder.present? ? shareholder.name : payee
  end

  def entry_type
    @entry_type || (amount < 0 ? 'Credit' : 'Bill')
  end

  def entry_type=(val)
    @entry_type = val
  end

  def credit_amount
    -amount if amount < 0
  end

  def bill_amount
    amount if amount >= 0
  end

  def entry_amount=(val)
    @entry_amount = val
  end

  def entry_amount
    ApplicationController.helpers.number_with_precision(@entry_amount || amount.abs, precision: 2)
  end

  def shareholder_balance_amount(sh)
    bill_share_balance_entries.each do |bsbe|
      return bsbe.amount if bsbe.shareholder_id == sh.id
    end
    return 0
  end

  def shareholder_share_amount(sh)
    # TODO get ride of shareholder_balance_amount
    shareholder_balance_amount(sh)
  end

  def shareholder_offset_amount(sh)
    (self.type == "ShareholderBill" and self.shareholder_id == sh.id) ? bill_offset_balance_entry.amount : 0
  end

  def shareholder_change_amount(sh)
    shareholder_balance_amount(sh) + shareholder_offset_amount(sh)
  end

  def build_bill_share_entries!
    if account.present?
      active_shareholders.each do |s|
        bill_share_balance_entries.build shareholder: s, account: account, date: date
      end
    end
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

  def set_amount
    self.amount = (entry_type == 'Credit' ? - @entry_amount.to_d : @entry_amount)
  end

  def update_balance_entries
    s = bill_share_balance_entries.find_all {|e| !e.marked_for_destruction? }
    p = (pot_balance_entry.blank? ? build_pot_balance_entry(account: account) : pot_balance_entry)
    if s.size > 0 && self.amount_cents.present?
      base_cents, gcd, remainder_cents = Bill.calc_shares(s.map(&:share), amount_cents)

      s.each do |b|
        b.amount_cents = (b.share == 0) ? 0 : -(b.share / gcd) * base_cents
        b.date = self.date
      end
      p.amount_cents = remainder_cents
      p.date = self.date
    end
  end

  def update_balance_event
    build_balance_event if balance_event.blank?
    balance_event.account = account
    balance_event.date = date
  end
end
