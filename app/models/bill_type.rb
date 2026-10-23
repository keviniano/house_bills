class BillType < ApplicationRecord
  include Userstamps

  has_many :bills, dependent: :restrict_with_error

  has_paper_trail
  
  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :for_account,   -> (account) { where(account_id: account.id) }
  scope :default_order, -> { order :name }
end
