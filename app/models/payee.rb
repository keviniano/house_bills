class Payee < ActiveRecord::Base
  stampable
  belongs_to :account

  validates :name, presence: true, uniqueness: { scope: :account_id }
end
