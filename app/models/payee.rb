class Payee < ApplicationRecord
  include Userstamps

  belongs_to :account, optional: true

  has_paper_trail

  validates :name, presence: true, uniqueness: { scope: :account_id }
end
