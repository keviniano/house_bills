class AccountEntry < ActiveRecord::Base
  before_validation :set_amount
  
  belongs_to :bill
  belongs_to :shareholder
  belongs_to :account
  has_one    :account_offset_balance_entry, :dependent => :destroy, :autosave => true

  validates_presence_of     :entry_amount
  validates_presence_of     :entry_type
  validates_numericality_of :check_number, :allow_nil => true
  validates_presence_of     :date
  validates_associated      :account_offset_balance_entry 

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
    self.find(:all, :conditions => {:date => start_date..end_date}, :order => "date, check_number, id")
  end

  def self.balance_before(d)
    self.sum(:amount, :conditions => ['date < ?',d]) || 0
  end

  def self.balance_as_of(d)
    self.sum(:amount, :conditions => ['date <= ?',d]) || 0
  end

  def self.cleared_balance_before(d)
    self.sum(:amount, :conditions => ['cleared = ? and date < ?',true,d]) || 0
  end

  def self.cleared_balance_as_of(d)
    self.sum(:amount, :conditions => ['cleared = ? and date <= ?',true,d]) || 0
  end

  def cleared_balance
    if cleared
      AccountEntry.sum(:amount, :conditions => ['cleared = ? and date < ? or (date = ? and id <= ?)',true,date,date,id])
    end
  end
  
  def balance
    AccountEntry.sum(:amount, :conditions => ['date < ? or (date = ? and id <= ?)',date,date,id])
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

  def entry_amount
    ApplicationController.helpers.number_with_precision(@entry_amount || amount.abs, :precision => 2) unless @entry_amount.nil? && amount.nil?
  end
  
private
  
  def set_amount
    self.amount = (entry_type == 'Withdrawal' ? - @entry_amount.to_d : @entry_amount)
  end
end  
