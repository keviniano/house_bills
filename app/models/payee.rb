class Payee < ActiveRecord::Base
  belongs_to :account

  validates :name, presence: true, uniqueness: { scope: :account_id }
end
