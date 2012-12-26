class Account < ActiveRecord::Base
  stampable
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

  validates_presence_of :name

  def pot_balance
    pot_balance_entries.sum(:amount)
  end

  def balance
    account_entries.sum(:amount)
  end
end
