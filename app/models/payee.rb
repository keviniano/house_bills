class Payee < ActiveRecord::Base
  belongs_to :account

  has_paper_trail

  validates :name, presence: true, uniqueness: { scope: :account_id }
end
