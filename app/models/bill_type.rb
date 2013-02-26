class BillType < ActiveRecord::Base
  stampable
  has_many :bills

  scope :for_account, lambda{|account| where(account_id: account.id)}
  scope :default_order, order(:name)
end
