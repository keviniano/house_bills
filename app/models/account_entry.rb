class AccountEntry < ActiveRecord::Base
  before_validation :set_amount

  belongs_to :bill
  belongs_to :shareholder
  belongs_to :account
  has_one    :account_offset_balance_entry, :dependent => :destroy, :autosave => true
  has_one    :balance_event, :dependent => :destroy, :autosave => true

  has_paper_trail
  
  validate                  :date_string_format_must_be_valid
  validates_presence_of     :entry_amount
  validates_presence_of     :entry_type
  validates_numericality_of :check_number, :allow_nil => true
  validates_presence_of     :date_string
  validates_associated      :account_offset_balance_entry

  scope :with_text,    -> (text) { where("payee ILIKE :text OR note ILIKE :text", text: "%#{text}%")}
  scope :starting_on,  -> (start_date) { where("date >= ?", start_date)}
  scope :ending_on,    -> (end_date) { where("date <= ?", end_date)}
  scope :deposits,     -> { where 'amount >= 0' }
  scope :withdrawals,  -> { where 'amount < 0' }
  scope :cleared,      -> { where cleared: true }
  scope :pending,      -> { where cleared: false }
  scope :with_payee_shareholder_id, -> (shareholder) { where(shareholder_id: shareholder)}

  default_value_for :date do
    Date.today
  end
  default_value_for :amount, 0
  default_value_for :cleared, false

  def open_shareholders
    account.shareholders.open_as_of(date) if account.present?
  end

  def recipient
    shareholder.present? ? shareholder.name : payee
  end

  def self.valid_entry_types
    %w( Deposit Withdrawal )
  end

  def self.find_in_date_range(start_date,end_date)
    self.where(date: start_date..end_date).order(:date, :check_number, :id)
  end

  def self.balance_before(d)
    self.where('date < ?',d).sum(:amount) || 0
  end

  def self.balance_as_of(d)
    self.where('date <= ?',d).sum(:amount) || 0
  end

  def self.cleared_balance_before(d)
    self.where('cleared = ? and date < ?',true,d).sum(:amount) || 0
  end

  def self.cleared_balance_as_of(d)
    self.where('cleared = ? and date <= ?',true,d).sum(:amount) || 0
  end

  def balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).where("balance_entries.date < ? OR (balance_entries.date = ? AND balance_entries.account_entry_id <= ?)",self.date,self.date,self.id).sum(:amount)
  end

  def prior_balance_for(shareholder)
    BalanceEntry.by_shareholder(shareholder).where("balance_entries.date < ? OR (balance_entries.date = ? AND balance_entries.account_entry_id < ?)",self.date,self.date,self.id).sum(:amount)
  end

  def date_string=(value)
    @date_string = value
    self.date = DateTime.strptime(value,'%m-%d-%Y')
  rescue ArgumentError
    @date_invalid = true
  end

  def date_string
    @date_string || date.strftime('%m-%d-%Y')
  end

  def cleared_balance
    AccountEntry.where('cleared = ? and date < ? or (date = ? and id <= ?)',true,date,date,id).sum(:amount)
  end

  def prior_cleared_balance
    AccountEntry.where('cleared = ? and date < ? or (date = ? and id < ?)',true,date,date,id).sum(:amount)
  end

  def this_balance
    AccountEntry.where('date < ? or (date = ? and id <= ?)',date,date,id).sum(:amount)
  end

  def prior_balance
    AccountEntry.where('date < ? or (date = ? and id < ?)',date,date,id).sum(:amount)
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

private

  def date_string_format_must_be_valid
    errors.add(:date_string, "is invalid") if @date_invalid
  end

  def set_amount
    if @entry_amount.present?
      self.amount = (entry_type == 'Withdrawal' ? - @entry_amount.to_d : @entry_amount)
    end
  end
end
