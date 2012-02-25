class Account < ActiveRecord::Base
  stampable
  has_many :bills
  has_many :shareholder_bills
  has_many :account_bills
  has_many :account_entries
  has_many :bill_account_entries
  has_many :shareholder_account_entries
  has_many :unbound_account_entries
  has_many :account_offset_balance_entries
  has_many :bill_offset_balance_entries
  has_many :bill_share_balance_entries
  has_many :shareholders, :dependent => :destroy
  has_many :users, :through => :shareholders
  has_many :payees
  has_many :balance_entries
  has_many :bill_types

  validates_presence_of :name

  accepts_nested_attributes_for :shareholders, :allow_destroy => true, 
      :reject_if => proc { |attrs| attrs[:name].blank? && attrs[:email].blank? }

end
