class Account < ActiveRecord::Base
  has_many :bills, :dependent => :destroy
  has_many :shareholder_bills
  has_many :account_bills
  has_many :account_entries, :dependent => :destroy
  has_many :bill_account_entries
  has_many :shareholder_account_entries
  has_many :unbound_account_entries
  has_many :balance_entries, :dependent => :destroy
  has_many :balance_events, :dependent => :destroy
  has_many :account_offset_balance_entries
  has_many :bill_offset_balance_entries
  has_many :bill_share_balance_entries
  has_many :shareholders, :dependent => :destroy
  has_many :users, :through => :shareholders
  has_many :payees, :dependent => :destroy
  has_many :bill_types, :dependent => :destroy
  has_many :pot_balance_entries

  has_paper_trail
  
  validates :name, presence: true, uniqueness: true
  validate  :lock_records_before_string_format_must_be_valid

  def pot_balance
    pot_balance_entries.sum(:amount)
  end

  def balance
    account_entries.sum(:amount)
  end

  def lock_records_before_string=(value)
    @lock_records_before_string = value
    self.lock_records_before = (value.blank? ? nil : DateTime.strptime(value,'%m-%d-%Y'))
  rescue ArgumentError
    @lock_records_before_invalid = true
  end

  def lock_records_before_string
    @lock_records_before_string || lock_records_before.try(:strftime,'%m-%d-%Y')
  end

  private

  def lock_records_before_string_format_must_be_valid
    errors.add(:lock_records_before_string, "is invalid") if @lock_records_before_invalid
  end

end
