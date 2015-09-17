class Bill < ActiveRecord::Base
  belongs_to  :shareholder
  belongs_to  :account
  belongs_to  :bill_type
  has_many    :bill_share_balance_entries, dependent: :destroy, autosave: true
  has_one     :bill_offset_balance_entry,  dependent: :destroy, autosave: true
  has_one     :pot_balance_entry,          dependent: :destroy, autosave: true
  has_one     :bill_account_entry,         dependent: :destroy, autosave: true
  has_one     :balance_event,              dependent: :destroy, autosave: true

  has_paper_trail
  
  before_validation :set_amount
  after_validation  :update_balance_entries, :update_balance_event

  accepts_nested_attributes_for :bill_share_balance_entries, allow_destroy: true,
      reject_if: proc { |attrs| attrs['shareholder_id'].blank? || attrs['share'].blank? || attrs['share'] == '0' }

  def self.valid_entry_types
    %w( Bill Credit )
  end

  def self.sum_of_bills_by_type_and_month_for_shareholder(shareholder)
    select('bills.bill_type_id, extract(month from bills.date) AS month, extract(year from bills.date) AS year, -sum(balance_entries.amount) as amount').
    joins(:bill_share_balance_entries).
    where("balance_entries.shareholder_id = ?", shareholder.id).
    group('bill_type_id, extract(month from bills.date), extract(year from bills.date)').
    order('bill_type_id, extract(year from bills.date), extract(month from bills.date)').
    includes(:bill_type)
  end

  def balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).where("balance_entries.date < ? OR (balance_entries.date = ? AND COALESCE(balance_entries.bill_id,?) <= ?)",self.date,self.date,self.id,self.id).sum(:amount)
  end

  def balances_for(shareholders)
    balance_entries = BalanceEntry.for_shareholders(shareholders).where("balance_entries.date < ? OR (balance_entries.date = ? AND COALESCE(balance_entries.bill_id,?) <= ?)",self.date,self.date,self.id,self.id).select('shareholder_id, SUM(amount) AS amount').group('shareholder_id')
    result = {}
    balance_entries.each {|be| result[be.shareholder_id] = be.amount }
    result
  end

  def prior_balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).where("balance_entries.date < ? OR (balance_entries.date = ? AND COALESCE(balance_entries.bill_id,?) < ?)",self.date,self.date,self.id,self.id).sum(:amount)
  end

  validate                  :date_string_format_must_be_valid
  validates_presence_of     :entry_type
  validates_inclusion_of    :entry_type, in: valid_entry_types
  validates_numericality_of :entry_amount, greater_than_or_equal_to: 0
  validates_presence_of     :bill_type_id
  validates_presence_of     :date_string
  validates_associated      :bill_share_balance_entries
  validates_presence_of     :entry_amount
# TODO: Make sure there's always at least one bill share entry

  default_value_for :date do
    Date.today
  end
  default_value_for :amount, 0

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

  def date_string=(value)
    @date_string = value
    self.date = (value.blank? ? nil : DateTime.strptime(value,'%m-%d-%Y'))
  rescue ArgumentError
    @date_invalid = true
  end

  def date_string
    @date_string || date.strftime('%m-%d-%Y')
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

  private

  def date_string_format_must_be_valid
    errors.add(:date_string, "is invalid") if @date_invalid
  end

  def set_amount
    self.amount = (entry_type == 'Credit' ? - @entry_amount.to_d : @entry_amount)
  end

  def update_balance_entries
    s = bill_share_balance_entries.find_all {|e| !e.marked_for_destruction? }
    p = (pot_balance_entry.blank? ? build_pot_balance_entry(account: account) : pot_balance_entry)
    if s.size > 0 && self.amount.present?
      share_ratios = s.map { |s| s.share }
      base_portion, gcd, remainder = Bill.calc_shares(share_ratios, amount)

      s.each do |b|
        b.amount = (b.share == 0) ? 0 : (-b.share/gcd) * base_portion
        b.date = self.date
      end
      p.amount = remainder
      p.date = self.date
    end
  end

  def update_balance_event
    build_balance_event if balance_event.blank?
    balance_event.account = account
    balance_event.date = date
  end

  def self.calc_shares(share_ratios, bill_amount)
    gcd = nil
    total_shares = share_ratios.inject {|sum, n| sum + n }
    share_ratios.each do |s|
      gcd = (gcd ||= s).gcd(s) unless s <= 0
    end
    if total_shares == 0
      base_portion = 0
    else
      if (bill_amount * 100) % (total_shares / gcd) == 0
        base_portion = bill_amount / (total_shares / gcd)
        remainder = 0
      else
        base_portion = (((bill_amount.to_f / (total_shares / gcd) * 100).floor.to_f / 100) + 0.01)
        remainder = -((bill_amount - ((total_shares / gcd) * base_portion)) * 100).round.to_f / 100
      end
    end
    [base_portion, gcd, remainder]
  end

end
