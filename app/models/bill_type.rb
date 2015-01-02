class BillType < ActiveRecord::Base
  has_many :bills

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :for_account,   -> (account) { where(account_id: account.id) }
  scope :default_order, -> { order :name }
end
